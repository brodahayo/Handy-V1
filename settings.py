"""Persistent settings manager for Handy.

Settings are stored as JSON at ~/Library/Application Support/Handy/settings.json
"""

import json
import os

_BASE_DIR = os.path.expanduser("~/Library/Application Support/Handy")
_current_user_id = None

# Migrate from old VoiceType location if needed
_OLD_DIR = os.path.expanduser("~/Library/Application Support/VoiceType")
_OLD_FILE = os.path.join(_OLD_DIR, "settings.json")
_global_settings_file = os.path.join(_BASE_DIR, "settings.json")
if os.path.exists(_OLD_FILE) and not os.path.exists(_global_settings_file):
    os.makedirs(_BASE_DIR, exist_ok=True)
    import shutil
    shutil.copy2(_OLD_FILE, _global_settings_file)


def set_user(user_id):
    """Set the current user ID. Call on login."""
    global _current_user_id
    _current_user_id = user_id


def clear_user():
    """Clear user on logout."""
    global _current_user_id
    _current_user_id = None


def _get_settings_path():
    """Return (dir, file) for the current user or global fallback."""
    if _current_user_id:
        d = os.path.join(_BASE_DIR, "users", _current_user_id)
    else:
        d = _BASE_DIR
    return d, os.path.join(d, "settings.json")

DEFAULTS = {
    "hotkey_mode": "hold_fn",         # "hold_fn" or "toggle"
    "hold_key": "fn",                 # "fn", "option_shift", "option", "command", "control"
    "hotkey_modifier": "option",      # option, command, control, shift (for toggle mode)
    "hotkey_key": "v",                # any single character (for toggle mode)
    "cleanup_enabled": True,          # whether to run AI cleanup after transcription
    "cleanup_style": "casual",        # casual, professional, minimal
    "context_aware": False,           # detect frontmost app and adjust cleanup style
    "cloud_provider": "groq",          # "groq", "openai", "deepgram"
    "api_key": "",                    # API key for selected cloud provider
    "openai_api_key": "",             # OpenAI API key
    "deepgram_api_key": "",           # Deepgram API key
    "overlay_style": "mini",          # "classic", "mini", "none"
    "overlay_position": "bottom-center",  # "bottom-center", "top-center", "top-left", "top-right", "bottom-left", "bottom-right"
    "overlay_always_show": True,      # whether to always show the recording window
    "language": "auto",               # transcription language ("auto", "en", "es", etc.)
    "transcription_mode": "cloud",    # "cloud", "local", "auto"
    "local_model_size": "base",       # "tiny", "base", "small"
    "daily_goal": 2000,               # daily word count goal
    "sound_enabled": True,            # play start/stop recording sounds
    "sound_pack": "woody",            # sound effect pack: woody, crystal, bubble, chirp, synth
    "launch_at_login": False,         # auto-start on macOS login
}

SUPPORTED_LANGUAGES = {
    "auto": "Auto-detect",
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "it": "Italian",
    "pt": "Portuguese",
    "nl": "Dutch",
    "ja": "Japanese",
    "ko": "Korean",
    "zh": "Chinese",
    "ar": "Arabic",
    "hi": "Hindi",
    "ru": "Russian",
    "tr": "Turkish",
    "pl": "Polish",
    "sv": "Swedish",
    "da": "Danish",
    "no": "Norwegian",
    "fi": "Finnish",
}

# Map readable modifier names to Cocoa NSEvent modifier masks
MODIFIER_FLAGS = {
    "option":  1 << 19,   # NSAlternateKeyMask
    "command": 1 << 20,   # NSCommandKeyMask
    "control": 1 << 18,   # NSControlKeyMask
    "shift":   1 << 17,   # NSShiftKeyMask
}

MODIFIER_SYMBOLS = {
    "option":  "\u2325",
    "command": "\u2318",
    "control": "\u2303",
    "shift":   "\u21E7",
}

CLEANUP_PROMPTS = {
    "casual": (
        "You are a voice-to-text assistant. Clean up the following transcribed speech "
        "into natural, conversational text.\n\nRules:\n"
        "- Fix grammar, punctuation, and capitalization\n"
        "- Remove filler words (um, uh, like, you know) unless they add meaning\n"
        "- Keep the original meaning and casual tone\n"
        "- Do NOT add information that wasn't spoken\n"
        "- Do NOT add any preamble or explanation, just output the cleaned text\n"
        "- If the text is a command or short phrase, keep it short\n\n"
        "Transcribed speech:\n{text}\n\nCleaned text:"
    ),
    "professional": (
        "You are a voice-to-text assistant. Clean up the following transcribed speech "
        "into polished, professional text suitable for emails or documents.\n\nRules:\n"
        "- Fix grammar, punctuation, and capitalization\n"
        "- Remove all filler words\n"
        "- Use professional tone and vocabulary\n"
        "- Improve sentence structure for clarity\n"
        "- Do NOT add information that wasn't spoken\n"
        "- Do NOT add any preamble or explanation, just output the cleaned text\n\n"
        "Transcribed speech:\n{text}\n\nCleaned text:"
    ),
    "minimal": (
        "You are a voice-to-text assistant. Lightly clean up the following transcribed speech.\n\n"
        "Rules:\n"
        "- Only fix obvious errors in grammar and punctuation\n"
        "- Keep the original wording as much as possible\n"
        "- Remove filler words only if they add nothing\n"
        "- Do NOT rephrase or restructure sentences\n"
        "- Do NOT add any preamble or explanation, just output the cleaned text\n\n"
        "Transcribed speech:\n{text}\n\nCleaned text:"
    ),
    "command": (
        "You are a voice-to-command assistant. Convert the following speech into a clean "
        "terminal/shell command or technical text.\n\n"
        "Rules:\n"
        "- Output ONLY the command or technical text, nothing else\n"
        "- Convert spoken words to their technical equivalents (e.g., 'dash' -> '-', 'slash' -> '/')\n"
        "- Use lowercase for commands\n"
        "- No punctuation unless it's part of the command syntax\n"
        "- If it sounds like a regular sentence, output it as-is without cleanup\n\n"
        "Spoken input:\n{text}\n\nCommand:"
    ),
}


def _ensure_dir():
    d, _ = _get_settings_path()
    os.makedirs(d, exist_ok=True)


def load() -> dict:
    """Load settings from disk, returning defaults for any missing keys."""
    _, settings_file = _get_settings_path()
    settings = dict(DEFAULTS)
    if os.path.exists(settings_file):
        try:
            with open(settings_file, "r") as f:
                saved = json.load(f)
            settings.update(saved)
        except (json.JSONDecodeError, OSError):
            pass  # corrupted file — use defaults
    return settings


def save(settings: dict):
    """Persist settings to disk."""
    _ensure_dir()
    _, settings_file = _get_settings_path()
    with open(settings_file, "w") as f:
        json.dump(settings, f, indent=2)


def get(key: str):
    """Get a single setting value."""
    return load().get(key, DEFAULTS.get(key))


def set(key: str, value):
    """Set a single setting value and persist."""
    s = load()
    s[key] = value
    save(s)


def get_modifier_mask() -> int:
    """Return the Cocoa modifier flag mask for the current hotkey modifier."""
    mod = load().get("hotkey_modifier", "option")
    return MODIFIER_FLAGS.get(mod, MODIFIER_FLAGS["option"])


HOLD_KEY_DISPLAY = {
    "fn": "Fn",
    "option_shift": "⌥⇧",
    "option": "⌥",
    "command": "⌘",
    "control": "⌃",
}


def get_hotkey_display() -> str:
    """Return a human-readable string like '⌥V' or '⌥⇧' for the current hotkey."""
    s = load()
    if s.get("hotkey_mode") == "hold_fn":
        hold_key = s.get("hold_key", "option_shift")
        return HOLD_KEY_DISPLAY.get(hold_key, "⌥⇧")
    mod = s.get("hotkey_modifier", "option")
    key = s.get("hotkey_key", "v")
    symbol = MODIFIER_SYMBOLS.get(mod, mod)
    return f"{symbol}{key.upper()}"


def get_cleanup_prompt() -> str:
    """Return the cleanup prompt for the current style."""
    style = load().get("cleanup_style", "casual")
    return CLEANUP_PROMPTS.get(style, CLEANUP_PROMPTS["casual"])
