#!/usr/bin/env python3
"""
Handy — AI-powered voice-to-text for macOS

A full windowed desktop app with pywebview UI and global hotkey.
Supports "hold Fn to dictate" and "modifier+key toggle" modes.

Usage: python3 app.py
"""

import os
import threading
import webview
import Cocoa
from Quartz import (
    CGEventTapCreate, CGEventTapEnable, CGEventMaskBit,
    CGEventGetFlags, CGEventSetFlags,
    kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
    kCGEventFlagsChanged, kCGEventTapDisabledByTimeout,
    CGEventSourceFlagsState, kCGEventSourceStateHIDSystemState,
)
from Foundation import CFMachPortCreateRunLoopSource, CFRunLoopAddSource, CFRunLoopGetCurrent
import settings as settings_mgr
from api import Api
from overlay import RecordingOverlay
from statusbar import StatusBarController
import sounds

# Path to the UI HTML file
UI_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui.html")

# Fn key modifier flag
FN_FLAG = 1 << 23  # NSEventModifierFlagFunction / kCGEventFlagMaskSecondaryFn

# ── Global state ──────────────────────────────────────────────────────
_window = None
_api = None
_monitors = []
_event_tap = None
_overlay = None
_statusbar = None


# ── Recording overlay ────────────────────────────────────────────────

def _show_overlay():
    """Show the floating recording pill + play start sound + update menu bar."""
    global _overlay
    if _overlay is None:
        _overlay = RecordingOverlay(
            on_stop=lambda: _api.stop_recording() if _api else None,
            level_provider=lambda: _api.recorder.current_rms if _api and _api.recorder else 0.0,
        )
    _overlay.show()
    sounds.play_start()
    if _statusbar:
        _statusbar.schedule_set_recording(True)


def _hide_overlay():
    """Hide the floating recording pill + play stop sound + update menu bar."""
    if _overlay:
        _overlay.hide()
    sounds.play_stop()
    if _statusbar:
        _statusbar.schedule_set_recording(False)


# ── Fn key via CGEventTap ────────────────────────────────────────────

def _register_fn_tap(api_instance):
    """Use CGEventTap to intercept Fn key before macOS grabs it."""
    global _event_tap
    fn_was_down = [False]

    def tap_callback(proxy, event_type, event, refcon):
        # Re-enable if macOS disabled the tap
        if event_type == kCGEventTapDisabledByTimeout:
            if _event_tap:
                CGEventTapEnable(_event_tap, True)
            return event

        if event_type == kCGEventFlagsChanged:
            flags = CGEventGetFlags(event)
            fn_down = bool(flags & FN_FLAG)

            if fn_down and not fn_was_down[0]:
                fn_was_down[0] = True
                if not api_instance.is_recording:
                    api_instance.start_recording()
                    # Show overlay on main thread
                    Cocoa.NSObject.performSelectorOnMainThread_withObject_waitUntilDone_(
                        _overlay_show_selector, None, False
                    ) if False else _do_on_main(_show_overlay)
                # Swallow the Fn event so macOS doesn't open emoji/dictation
                flags = flags & ~FN_FLAG
                CGEventSetFlags(event, flags)

            elif not fn_down and fn_was_down[0]:
                fn_was_down[0] = False
                if api_instance.is_recording:
                    api_instance.stop_recording()
                    _do_on_main(_hide_overlay)

        return event

    # Create event tap
    _event_tap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,  # can modify events
        CGEventMaskBit(kCGEventFlagsChanged),
        tap_callback,
        None,
    )

    if _event_tap is None:
        print("[Handy] Failed to create CGEventTap. Grant Accessibility permission.", flush=True)
        return

    # Add to a run loop
    source = CFMachPortCreateRunLoopSource(None, _event_tap, 0)

    def run_tap():
        loop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(loop, source, Cocoa.kCFRunLoopCommonModes)
        CGEventTapEnable(_event_tap, True)
        Cocoa.CFRunLoopRun()

    t = threading.Thread(target=run_tap, daemon=True)
    t.start()

    # Watchdog for missed releases
    def release_watchdog():
        import time
        while True:
            time.sleep(0.5)
            if fn_was_down[0] and api_instance.is_recording:
                current_flags = CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState)
                if not (current_flags & FN_FLAG):
                    fn_was_down[0] = False
                    api_instance.stop_recording()
                    _do_on_main(_hide_overlay)

    threading.Thread(target=release_watchdog, daemon=True).start()


# ── Hold modifier key (non-Fn) ───────────────────────────────────────

def _register_hold_modifier(api_instance):
    """Hold modifier key(s) to record, release to stop."""
    was_down = [False]
    hold_key = settings_mgr.get("hold_key")

    HOLD_MASKS = {
        "option_shift": Cocoa.NSAlternateKeyMask | Cocoa.NSShiftKeyMask,
        "option": Cocoa.NSAlternateKeyMask,
        "command": Cocoa.NSCommandKeyMask,
        "control": Cocoa.NSControlKeyMask,
    }
    hold_mask = HOLD_MASKS.get(hold_key, HOLD_MASKS["option_shift"])

    def is_held(flags):
        return (flags & hold_mask) == hold_mask

    NSEventMaskFlagsChanged = 1 << 12
    event_masks = NSEventMaskFlagsChanged | Cocoa.NSKeyDownMask | Cocoa.NSKeyUpMask

    def flags_handler(event):
        held = is_held(event.modifierFlags())

        if held and not was_down[0]:
            was_down[0] = True
            if not api_instance.is_recording:
                api_instance.start_recording()
                _show_overlay()

        elif not held and was_down[0]:
            was_down[0] = False
            if api_instance.is_recording:
                api_instance.stop_recording()
                _hide_overlay()

    m1 = Cocoa.NSEvent.addGlobalMonitorForEventsMatchingMask_handler_(
        event_masks, flags_handler
    )
    _monitors.append(m1)

    def local_handler(event):
        flags_handler(event)
        return event

    m2 = Cocoa.NSEvent.addLocalMonitorForEventsMatchingMask_handler_(
        event_masks, local_handler
    )
    _monitors.append(m2)

    # Watchdog
    def release_watchdog():
        import time
        while True:
            time.sleep(0.5)
            if was_down[0] and api_instance.is_recording:
                current = CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState)
                if not is_held(current):
                    was_down[0] = False
                    api_instance.stop_recording()
                    _do_on_main(_hide_overlay)

    threading.Thread(target=release_watchdog, daemon=True).start()


# ── Toggle mode ──────────────────────────────────────────────────────

def _register_toggle_hotkey(api_instance):
    """Modifier+key press to toggle recording."""
    modifier_mask = settings_mgr.get_modifier_mask()
    hotkey_key = (settings_mgr.get("hotkey_key") or "v").lower()
    print(f"[hotkey] Toggle mode: modifier_mask={hex(modifier_mask)}, key='{hotkey_key}'")

    def _toggle():
        if api_instance.is_recording:
            api_instance.stop_recording()
            _do_on_main(_hide_overlay)
        else:
            api_instance.start_recording()
            _do_on_main(_show_overlay)

    def handler(event):
        try:
            chars = event.charactersIgnoringModifiers()
            flags = event.modifierFlags()
            if chars and chars.lower() == hotkey_key and (flags & modifier_mask):
                print(f"[hotkey] GLOBAL match — toggling (recording={api_instance.is_recording})")
                _toggle()
        except Exception as e:
            print(f"[hotkey] handler error: {e}")

    m1 = Cocoa.NSEvent.addGlobalMonitorForEventsMatchingMask_handler_(
        Cocoa.NSKeyDownMask, handler
    )
    _monitors.append(m1)

    def local_handler(event):
        try:
            chars = event.charactersIgnoringModifiers()
            flags = event.modifierFlags()
            if chars and chars.lower() == hotkey_key and (flags & modifier_mask):
                print(f"[hotkey] LOCAL match — toggling (recording={api_instance.is_recording})")
                _toggle()
                return None
        except Exception as e:
            print(f"[hotkey] local handler error: {e}")
        return event

    m2 = Cocoa.NSEvent.addLocalMonitorForEventsMatchingMask_handler_(
        Cocoa.NSKeyDownMask, local_handler
    )
    _monitors.append(m2)


# ── Main thread dispatch helper ──────────────────────────────────────

def _do_on_main(func):
    """Dispatch a function to run on the main thread."""
    from PyObjCTools import AppHelper
    AppHelper.callAfter(func)


# ── Registration router ─────────────────────────────────────────────

def _register_hotkey(api_instance):
    """Register global hotkey monitors — both hold and toggle active simultaneously."""
    _remove_monitors()

    hold_key = settings_mgr.get("hold_key")

    # Always register hold-to-dictate (Fn or modifier hold)
    if hold_key == "fn":
        _register_fn_tap(api_instance)
    else:
        _register_hold_modifier(api_instance)

    # Always register toggle hotkey for hands-free mode
    _register_toggle_hotkey(api_instance)


def _remove_monitors():
    global _monitors, _event_tap
    for m in _monitors:
        if m is not None:
            Cocoa.NSEvent.removeMonitor_(m)
    _monitors = []
    if _event_tap:
        CGEventTapEnable(_event_tap, False)
        _event_tap = None


# ── Main ─────────────────────────────────────────────────────────────

def on_loaded():
    _register_hotkey(_api)


def main():
    global _window, _api, _statusbar

    _api = Api()
    _api.on_settings_changed = lambda: _register_hotkey(_api)

    # Menu bar status item
    def _toggle_from_menu():
        if _api.is_recording:
            _api.stop_recording()
            _do_on_main(_hide_overlay)
        else:
            _api.start_recording()
            _do_on_main(_show_overlay)

    def _open_from_menu():
        if _window:
            _window.show()

    def _quit_from_menu():
        if _window:
            _window.destroy()

    _statusbar = StatusBarController(
        on_toggle=_toggle_from_menu,
        on_open=_open_from_menu,
        on_quit=_quit_from_menu,
    )
    _statusbar.schedule_setup()

    _window = webview.create_window(
        title="Handy",
        url=UI_PATH,
        js_api=_api,
        width=860,
        height=640,
        min_size=(860, 480),
        background_color="#28282a",
        frameless=False,
        easy_drag=False,
        text_select=True,
    )

    _api.set_window(_window)
    _window.events.loaded += on_loaded

    # Lock width — only height is adjustable
    FIXED_WIDTH = 860

    def on_resized(width, height):
        if width != FIXED_WIDTH:
            _window.resize(FIXED_WIDTH, height)

    _window.events.resized += on_resized

    def on_started():
        _register_hotkey(_api)

    webview.start(debug=False, func=on_started)

    _api.cleanup()
    _remove_monitors()
    os._exit(0)


if __name__ == "__main__":
    main()
