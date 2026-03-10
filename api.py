"""Python API class exposed to pywebview JS bridge.

All public methods here are callable from JavaScript via window.pywebview.api.<method>()
"""

import os
import subprocess
import threading
import time
from recorder import Recorder
import cloud_transcribe
import settings as settings_mgr
import data as data_mgr
import config
import version as version_mod
import supabase_config


class Api:
    """Bridge between the HTML/JS frontend and Python backend."""

    def __init__(self, window_ref=None):
        self._window = window_ref
        self.recorder = Recorder()
        self.is_recording = False
        self._recording_start_time = None
        self.on_settings_changed = None
        self._pending_events = []
        self._frontmost_app = None
        self._downloading_models = set()  # track in-progress downloads
        self._notes_mode = False  # when True, transcription goes to notes instead of paste

    def set_window(self, window):
        self._window = window

    # ── Recording ──────────────────────────────────────────────────────

    def start_recording(self):
        if self.is_recording:
            return {"status": "already_recording"}
        self.is_recording = True
        self._recording_start_time = time.time()
        threading.Thread(target=self._do_start_recording, daemon=True).start()
        return {"status": "recording"}

    def _do_start_recording(self):
        try:
            self.recorder.start()
        except Exception as e:
            self.is_recording = False
            self._emit("processing_error", {"error": f"Mic error: {str(e)[:100]}"})

    def stop_recording(self):
        if not self.is_recording:
            return {"status": "not_recording"}
        self.is_recording = False
        try:
            from context_detect import get_frontmost_app
            self._frontmost_app = get_frontmost_app()
        except Exception:
            self._frontmost_app = None
        threading.Thread(target=self._do_stop_and_process, daemon=True).start()
        return {"status": "processing"}

    def _do_stop_and_process(self):
        try:
            frames = self.recorder.stop()
            if not frames:
                self._emit("processing_error", {"error": "No audio captured"})
                return
            self._process_audio(frames)
        except Exception as e:
            self._emit("processing_error", {"error": str(e)[:200]})

    def toggle_recording(self):
        if self.is_recording:
            return self.stop_recording()
        else:
            return self.start_recording()

    def get_recording_state(self):
        level = 0.0
        if self.is_recording and self.recorder:
            level = float(self.recorder.current_rms)
        return {"is_recording": self.is_recording, "level": level}

    # ── Meeting Notes Recording ───────────────────────────────────────

    def start_notes_recording(self):
        """Start recording for meeting notes (won't paste, sends text to notes UI)."""
        self._notes_mode = True
        return self.start_recording()

    def stop_notes_recording(self):
        """Stop notes recording."""
        result = self.stop_recording()
        return result

    # ── Audio Processing ──────────────────────────────────────────────

    def _process_audio(self, frames):
        try:
            self._emit("processing_status", {"stage": "transcribing"})

            s = settings_mgr.load()
            language = s.get("language", "auto")
            transcription_mode = s.get("transcription_mode", "cloud")
            local_model_size = s.get("local_model_size", "base")
            cloud_provider = s.get("cloud_provider", "groq")

            raw_text = self._transcribe_audio(
                frames, language, transcription_mode, local_model_size, cloud_provider, s
            )

            if not raw_text or raw_text.startswith("["):
                # Only show actual errors (like missing API key), not "no speech" silence
                if raw_text and raw_text.startswith("["):
                    err_event = "notes_error" if self._notes_mode else "processing_error"
                    self._emit(err_event, {"error": raw_text})
                self._notes_mode = False
                return

            if s.get("cleanup_enabled", True):
                self._emit("processing_status", {"stage": "cleaning"})
                prompt = self._get_cleanup_prompt(s)
                api_key = self._get_api_key(s, cloud_provider)
                final_text = cloud_transcribe.cleanup_text(
                    raw_text, api_key, prompt=prompt, provider=cloud_provider
                )
            else:
                final_text = raw_text

            is_notes = self._notes_mode
            self._notes_mode = False  # reset after use

            if is_notes:
                # Send to meeting notes UI instead of pasting
                self._emit("notes_transcription", {"text": final_text})
            else:
                entry = data_mgr.add_transcription(raw_text, final_text)
                self._paste_text(final_text)
                self._emit("transcription_complete", {
                    "entry": entry,
                    "today_words": data_mgr.get_today_words(),
                    "stats": data_mgr.get_stats(),
                })

        except Exception as e:
            self._emit("processing_error", {"error": str(e)[:200]})

    def _transcribe_audio(self, frames, language, mode, model_size, provider, s):
        use_local = False

        if mode == "local":
            use_local = True
        elif mode == "auto":
            api_key = self._get_api_key(s, provider)
            if not api_key:
                use_local = True
            else:
                try:
                    return cloud_transcribe.transcribe(frames, api_key, provider=provider, language=language)
                except Exception:
                    use_local = True

        if use_local:
            try:
                from local_whisper import transcribe_local, is_available
                if not is_available():
                    return "[ERROR] Local Whisper not installed. Run: pip install faster-whisper"
                return transcribe_local(frames, language=language, model_size=model_size)
            except ImportError:
                return "[ERROR] local_whisper module not found"
            except Exception as e:
                return f"[ERROR] Local transcription failed: {str(e)[:100]}"

        # Cloud mode
        api_key = self._get_api_key(s, provider)
        if not api_key:
            self._emit("processing_error", {"error": "No API key set. Go to Settings and enter your API key."})
            return ""
        return cloud_transcribe.transcribe(frames, api_key, provider=provider, language=language)

    def _get_cleanup_prompt(self, s):
        if s.get("context_aware", False) and self._frontmost_app:
            context_style = self._frontmost_app.get("cleanup_style")
            if context_style:
                return settings_mgr.CLEANUP_PROMPTS.get(context_style, settings_mgr.get_cleanup_prompt())
        return settings_mgr.get_cleanup_prompt()

    def _get_api_key(self, s=None, provider=None):
        """Get the API key for the specified cloud provider."""
        if s is None:
            s = settings_mgr.load()
        if provider is None:
            provider = s.get("cloud_provider", "groq")

        if provider == "openai":
            key = s.get("openai_api_key", "")
            if key:
                return key
        elif provider == "deepgram":
            key = s.get("deepgram_api_key", "")
            if key:
                return key
        else:
            # groq
            key = s.get("api_key", "")
            if key:
                return key

        return ""

    def _paste_text(self, text):
        process = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
        process.communicate(text.encode("utf-8"))
        script = '''
        tell application "System Events"
            keystroke "v" using command down
        end tell
        '''
        subprocess.run(["osascript", "-e", script], check=False)

    def _emit(self, event, data):
        import json
        payload = json.dumps(data)
        self._pending_events.append({"event": event, "data": payload})

    def get_pending_events(self):
        events = list(self._pending_events)
        self._pending_events.clear()
        return events

    # ── Data ───────────────────────────────────────────────────────────

    def get_transcriptions(self, limit=50):
        return data_mgr.get_transcriptions(limit)

    def get_stats(self):
        return data_mgr.get_stats()

    def get_daily_words(self):
        return data_mgr.get_daily_words(84)

    def get_today_words(self):
        return data_mgr.get_today_words()

    def get_user_name(self):
        return data_mgr.get_user_name()

    def set_user_name(self, name):
        data_mgr.set_user_name(name)
        return {"status": "ok"}

    def clear_history(self):
        data_mgr.clear_history()
        return {"status": "ok"}

    # ── Settings ───────────────────────────────────────────────────────

    def get_settings(self):
        s = settings_mgr.load()

        # Mask API keys per provider
        provider = s.get("cloud_provider", "groq")
        groq_key = s.get("api_key", "")
        openai_key = s.get("openai_api_key", "")
        deepgram_key = s.get("deepgram_api_key", "")

        s["has_api_key"] = bool(self._get_api_key(s, provider))
        s["groq_key_display"] = self._mask_key(groq_key) if groq_key else ""
        s["openai_key_display"] = self._mask_key(openai_key) if openai_key else ""
        s["deepgram_key_display"] = self._mask_key(deepgram_key) if deepgram_key else ""
        s["api_key_display"] = self._mask_key(groq_key) if groq_key else ""
        s["hotkey_display"] = settings_mgr.get_hotkey_display()
        s["user_name"] = data_mgr.get_user_name()
        s["offline_available"] = self._check_offline_available()
        s["supported_languages"] = settings_mgr.SUPPORTED_LANGUAGES
        s["cloud_providers"] = cloud_transcribe.CLOUD_PROVIDERS
        return s

    def save_settings(self, new_settings):
        s = settings_mgr.load()

        allowed_keys = [
            "hotkey_mode", "hold_key", "hotkey_modifier", "hotkey_key",
            "cleanup_enabled", "cleanup_style", "overlay_style", "overlay_position", "overlay_always_show",
            "language", "transcription_mode", "local_model_size", "context_aware",
            "cloud_provider", "daily_goal", "sound_enabled", "sound_pack", "launch_at_login",
        ]
        for key in allowed_keys:
            if key in new_settings:
                s[key] = new_settings[key]

        # Handle API keys per provider
        if "api_key" in new_settings and new_settings["api_key"]:
            raw = new_settings["api_key"]
            if not raw.startswith("gsk_***"):
                s["api_key"] = raw

        if "openai_api_key" in new_settings and new_settings["openai_api_key"]:
            raw = new_settings["openai_api_key"]
            if not raw.startswith("sk-***"):
                s["openai_api_key"] = raw

        if "deepgram_api_key" in new_settings and new_settings["deepgram_api_key"]:
            raw = new_settings["deepgram_api_key"]
            if "***" not in raw:
                s["deepgram_api_key"] = raw

        settings_mgr.save(s)

        if "user_name" in new_settings:
            data_mgr.set_user_name(new_settings["user_name"])

        # Toggle launch at login
        if "launch_at_login" in new_settings:
            self._set_launch_at_login(new_settings["launch_at_login"])

        # Invalidate sound cache when pack changes
        if "sound_pack" in new_settings:
            try:
                import sounds
                sounds.invalidate_cache()
            except Exception:
                pass

        if self.on_settings_changed:
            self.on_settings_changed()

        return {"status": "ok", "hotkey_display": settings_mgr.get_hotkey_display()}

    def _mask_key(self, key):
        if not key:
            return ""
        if len(key) <= 8:
            return "***"
        return key[:4] + "***" + key[-4:]

    # ── Model Management ─────────────────────────────────────────────

    def _check_offline_available(self):
        try:
            from local_whisper import is_available
            return is_available()
        except ImportError:
            return False

    def get_model_catalog(self):
        """Return the full local model catalog with download status."""
        try:
            from local_whisper import get_model_catalog
            return get_model_catalog()
        except ImportError:
            return []

    def download_model(self, model_id):
        """Download a local Whisper model in the background."""
        if model_id in self._downloading_models:
            return {"status": "already_downloading"}

        self._downloading_models.add(model_id)

        def do_download():
            try:
                self._emit("model_download_status", {
                    "status": "downloading", "model": model_id
                })
                from local_whisper import download_model
                download_model(model_id)
                self._emit("model_download_status", {
                    "status": "complete", "model": model_id
                })
            except Exception as e:
                self._emit("model_download_status", {
                    "status": "error", "model": model_id, "error": str(e)[:200]
                })
            finally:
                self._downloading_models.discard(model_id)

        threading.Thread(target=do_download, daemon=True).start()
        return {"status": "downloading"}

    def delete_model(self, model_id):
        """Delete a downloaded local model."""
        try:
            from local_whisper import delete_model
            deleted = delete_model(model_id)
            return {"status": "ok" if deleted else "not_found"}
        except ImportError:
            return {"status": "error", "error": "faster-whisper not installed"}

    def get_offline_status(self):
        available = self._check_offline_available()
        return {
            "available": available,
            "model_size": settings_mgr.get("local_model_size"),
        }

    # Keep backward compat
    def download_offline_model(self, model_size=None):
        if model_size is None:
            model_size = settings_mgr.get("local_model_size") or "base"
        return self.download_model(model_size)

    # ── Updates ────────────────────────────────────────────────────────

    def get_version(self):
        return {"version": version_mod.APP_VERSION, "name": version_mod.APP_NAME}

    def check_for_updates(self):
        """Check for app updates. Runs the network check in-thread since pywebview awaits."""
        return version_mod.check_for_updates()

    # ── Auth ──────────────────────────────────────────────────────────

    def switch_user(self, user_id):
        """Switch data & settings to a specific user account. Call on login."""
        if user_id:
            data_mgr.set_user(user_id)
            settings_mgr.set_user(user_id)
        else:
            data_mgr.clear_user()
            settings_mgr.clear_user()
        return {"status": "ok"}

    def get_supabase_config(self):
        """Return Supabase public config for the JS client."""
        return {
            "url": supabase_config.SUPABASE_URL,
            "anon_key": supabase_config.SUPABASE_ANON_KEY,
        }

    def open_oauth_url(self, url):
        """Open an OAuth URL in the system browser."""
        import webbrowser
        webbrowser.open(url)
        return {"status": "ok"}

    def start_oauth_listener(self):
        """Start a local HTTP server to capture the OAuth callback.
        Returns the port number to use as redirect URL."""
        import http.server
        import socketserver
        import urllib.parse

        # Find a free port
        with socketserver.TCPServer(("127.0.0.1", 0), None) as s:
            port = s.server_address[1]

        self._oauth_port = port

        def run_server():
            class CallbackHandler(http.server.BaseHTTPRequestHandler):
                def do_GET(handler):
                    parsed = urllib.parse.urlparse(handler.path)
                    if parsed.path == '/callback':
                        # PKCE flow: code comes as ?code=xxx query param
                        params = urllib.parse.parse_qs(parsed.query)
                        code = params.get('code', [''])[0]
                        if code:
                            self._emit('oauth_code', {'code': code})
                        html = """<!DOCTYPE html><html><head><title>Handy</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;display:flex;
align-items:center;justify-content:center;height:100vh;background:#1c1c1e;color:#f5f5f7;}
.card{text-align:center;padding:40px;border-radius:16px;background:#2a2a2c;
border:1px solid rgba(255,255,255,0.06);max-width:360px;}
.check{width:48px;height:48px;margin:0 auto 16px;border-radius:50%;
background:rgba(48,209,88,0.15);display:flex;align-items:center;justify-content:center;}
.check svg{width:24px;height:24px;stroke:#30D158;fill:none;stroke-width:2.5;
stroke-linecap:round;stroke-linejoin:round;}
h2{font-size:20px;font-weight:600;margin-bottom:6px;}
p{color:rgba(235,235,245,0.6);font-size:14px;line-height:1.5;}
</style></head><body>
<div class="card">
<div class="check"><svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg></div>
<h2>You're signed in</h2>
<p>You can close this tab and return to Handy.</p>
</div><script>history.replaceState(null,'','/');</script></body></html>"""
                        handler.send_response(200)
                        handler.send_header('Content-Type', 'text/html')
                        handler.end_headers()
                        handler.wfile.write(html.encode())
                        # Shut down server after handling callback
                        threading.Thread(target=handler.server.shutdown, daemon=True).start()
                    else:
                        handler.send_response(404)
                        handler.end_headers()

                def log_message(handler, format, *args):
                    pass  # Suppress logs

            server = http.server.HTTPServer(("127.0.0.1", port), CallbackHandler)
            server.timeout = 120  # 2 min timeout
            server.serve_forever()

        threading.Thread(target=run_server, daemon=True).start()
        return {"port": port}

    # ── Launch at Login ────────────────────────────────────────────────

    def _set_launch_at_login(self, enabled):
        """Add or remove the app from macOS login items via osascript."""
        try:
            app_path = os.path.dirname(os.path.abspath(__file__))
            # Check if running as .app bundle
            if app_path.endswith("/Contents/Resources"):
                app_path = app_path.rsplit("/Contents/", 1)[0]

            # Escape quotes for AppleScript safety
            safe_path = app_path.replace('\\', '\\\\').replace('"', '\\"')

            if enabled:
                script = f'''
                tell application "System Events"
                    make login item at end with properties {{path:"{safe_path}", hidden:true}}
                end tell
                '''
            else:
                app_name = os.path.basename(app_path).replace(".app", "")
                safe_name = app_name.replace('\\', '\\\\').replace('"', '\\"')
                script = f'''
                tell application "System Events"
                    delete login item "{safe_name}"
                end tell
                '''
            subprocess.run(["osascript", "-e", script], check=False,
                          capture_output=True, timeout=5)
        except Exception:
            pass

    # ── Utilities ──────────────────────────────────────────────────────

    def format_time_saved(self):
        stats = data_mgr.get_stats()
        seconds = stats.get("total_seconds_saved", 0)
        if seconds < 60:
            return f"{seconds}s"
        minutes = seconds // 60
        if minutes < 60:
            return f"{minutes}m"
        hours = minutes // 60
        remaining_mins = minutes % 60
        return f"{hours}h {remaining_mins}m"

    def preview_sound(self, pack, which="start"):
        """Preview a sound pack without changing settings."""
        try:
            import sounds
            sounds.preview(pack, which)
            return {"status": "ok"}
        except Exception as e:
            return {"status": "error", "error": str(e)[:100]}

    def cleanup(self):
        if self.recorder:
            self.recorder.cleanup()
