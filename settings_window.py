"""Premium dark-mode settings window for Handy using PyObjC / Cocoa."""

import objc
import Cocoa
from Foundation import NSObject, NSMakeRect, NSMakeSize
from AppKit import (
    NSWindow,
    NSWindowStyleMaskTitled,
    NSWindowStyleMaskClosable,
    NSBackingStoreBuffered,
    NSVisualEffectView,
    NSVisualEffectMaterialDark,
    NSVisualEffectBlendingModeBehindWindow,
    NSVisualEffectStateActive,
    NSTextField,
    NSButton,
    NSButtonTypeSwitch,
    NSFont,
    NSColor,
    NSPopUpButton,
    NSView,
    NSApp,
    NSWindowStyleMaskFullSizeContentView,
    NSTitlebarSeparatorStyleNone,
)
import settings as settings_mgr

# ── Constants ──────────────────────────────────────────────────────────────────
WIN_WIDTH = 460
WIN_HEIGHT = 420
PADDING = 24
LABEL_W = 160
CONTROL_X = PADDING + LABEL_W + 12
CONTROL_W = WIN_WIDTH - CONTROL_X - PADDING

ACCENT = NSColor.colorWithCalibratedRed_green_blue_alpha_(0.40, 0.45, 1.0, 1.0)
LABEL_COLOR = NSColor.colorWithCalibratedRed_green_blue_alpha_(0.85, 0.85, 0.88, 1.0)
SUBLABEL_COLOR = NSColor.colorWithCalibratedRed_green_blue_alpha_(0.55, 0.55, 0.60, 1.0)
FIELD_BG = NSColor.colorWithCalibratedRed_green_blue_alpha_(0.15, 0.15, 0.18, 1.0)

STYLES = ["casual", "professional", "minimal"]
STYLE_LABELS = {"casual": "Casual", "professional": "Professional", "minimal": "Minimal"}
STYLE_DESCS = {
    "casual": "Natural, conversational tone",
    "professional": "Polished, email-ready text",
    "minimal": "Light touch \u2014 keep original wording",
}

# Cocoa modifier masks for key event detection
_MOD_MASKS = {
    "option":  Cocoa.NSAlternateKeyMask,
    "command": Cocoa.NSCommandKeyMask,
    "control": Cocoa.NSControlKeyMask,
    "shift":   Cocoa.NSShiftKeyMask,
}
_MOD_MASK_TO_NAME = {v: k for k, v in _MOD_MASKS.items()}
_ALL_MOD_FLAGS = [Cocoa.NSCommandKeyMask, Cocoa.NSAlternateKeyMask,
                  Cocoa.NSControlKeyMask, Cocoa.NSShiftKeyMask]


def _symbol_for_mod(name):
    return settings_mgr.MODIFIER_SYMBOLS.get(name, name)


# ── Hotkey capture field ───────────────────────────────────────────────────────

class HotkeyField(NSTextField):
    """A text field that captures a key combination when focused."""

    def initWithFrame_(self, frame):
        self = objc.super(HotkeyField, self).initWithFrame_(frame)
        if self is None:
            return None
        self._captured_modifier = None
        self._captured_key = None
        self._on_change = None
        self.setEditable_(False)
        self.setSelectable_(False)
        self.setBezeled_(True)
        self.setBezelStyle_(Cocoa.NSTextFieldRoundedBezel)
        self.setAlignment_(Cocoa.NSTextAlignmentCenter)
        self.setFocusRingType_(Cocoa.NSFocusRingTypeNone)
        self.setFont_(NSFont.systemFontOfSize_weight_(14, 0.23))
        self.setTextColor_(LABEL_COLOR)
        self.setBackgroundColor_(FIELD_BG)
        self.setDrawsBackground_(True)
        # Rounded corners via layer
        self.setWantsLayer_(True)
        self.layer().setCornerRadius_(8)
        self.layer().setMasksToBounds_(True)
        self.layer().setBorderWidth_(1.5)
        self.layer().setBorderColor_(ACCENT.CGColor())
        return self

    def acceptsFirstResponder(self):
        return True

    def becomeFirstResponder(self):
        self.setStringValue_("Press a key combo\u2026")
        self.layer().setBorderColor_(
            NSColor.colorWithCalibratedRed_green_blue_alpha_(0.55, 0.50, 1.0, 1.0).CGColor()
        )
        return True

    def resignFirstResponder(self):
        self.layer().setBorderColor_(ACCENT.CGColor())
        self._update_display()
        return True

    def keyDown_(self, event):
        flags = event.modifierFlags()
        detected_mod = None
        for mask in _ALL_MOD_FLAGS:
            if flags & mask:
                detected_mod = _MOD_MASK_TO_NAME.get(mask)
                break
        char = event.charactersIgnoringModifiers()
        if detected_mod and char and len(char) == 1 and char.isalpha():
            self._captured_modifier = detected_mod
            self._captured_key = char.lower()
            self._update_display()
            self.window().makeFirstResponder_(None)
            if self._on_change:
                self._on_change(self._captured_modifier, self._captured_key)

    def _update_display(self):
        if self._captured_modifier and self._captured_key:
            sym = _symbol_for_mod(self._captured_modifier)
            self.setStringValue_(f"{sym}{self._captured_key.upper()}")
        else:
            self.setStringValue_("Click to set\u2026")

    def setHotkey_key_(self, modifier, key):
        self._captured_modifier = modifier
        self._captured_key = key
        self._update_display()


# ── ObjC action target (bridge between Cocoa actions and Python) ──────────────

class _ActionTarget(NSObject):
    """NSObject subclass that receives Cocoa button/popup actions and
    forwards them to plain-Python callbacks."""

    def init(self):
        self = objc.super(_ActionTarget, self).init()
        if self is None:
            return None
        self._cleanup_cb = None
        self._style_cb = None
        return self

    @objc.typedSelector(b"v@:@")
    def cleanupToggled_(self, sender):
        if self._cleanup_cb:
            self._cleanup_cb(sender)

    @objc.typedSelector(b"v@:@")
    def styleChanged_(self, sender):
        if self._style_cb:
            self._style_cb(sender)


# ── Settings window controller ────────────────────────────────────────────────

class SettingsWindowController:
    """Creates and manages the Handy preferences window."""

    def __init__(self, on_settings_changed=None):
        self._on_settings_changed = on_settings_changed
        self._window = None
        self._hotkey_field = None
        self._cleanup_toggle = None
        self._style_popup = None
        self._style_desc = None
        # ObjC target for button/popup actions — must be kept alive
        self._target = _ActionTarget.alloc().init()
        self._target._cleanup_cb = self._cleanup_toggled
        self._target._style_cb = self._style_changed

    # ── public ──

    def show(self):
        if self._window is not None:
            self._window.makeKeyAndOrderFront_(None)
            NSApp.activateIgnoringOtherApps_(True)
            return
        self._build()
        self._load_values()
        self._window.center()
        self._window.makeKeyAndOrderFront_(None)
        NSApp.activateIgnoringOtherApps_(True)

    # ── build ──

    def _build(self):
        rect = NSMakeRect(0, 0, WIN_WIDTH, WIN_HEIGHT)
        style = (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                 | NSWindowStyleMaskFullSizeContentView)
        self._window = NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
            rect, style, NSBackingStoreBuffered, False
        )
        self._window.setTitle_("Handy Preferences")
        self._window.setTitlebarAppearsTransparent_(True)
        self._window.setTitlebarSeparatorStyle_(NSTitlebarSeparatorStyleNone)
        self._window.setMovableByWindowBackground_(True)
        self._window.setReleasedWhenClosed_(False)
        self._window.setMinSize_(NSMakeSize(WIN_WIDTH, WIN_HEIGHT))
        self._window.setMaxSize_(NSMakeSize(WIN_WIDTH, WIN_HEIGHT))

        # Dark vibrancy background
        vibrancy = NSVisualEffectView.alloc().initWithFrame_(rect)
        vibrancy.setMaterial_(NSVisualEffectMaterialDark)
        vibrancy.setBlendingMode_(NSVisualEffectBlendingModeBehindWindow)
        vibrancy.setState_(NSVisualEffectStateActive)
        vibrancy.setAutoresizingMask_(18)  # width + height flex
        self._window.contentView().addSubview_(vibrancy)

        content = self._window.contentView()
        y = WIN_HEIGHT - 70  # start below the titlebar

        # ── Title ──
        title = self._make_label("Preferences", size=20, bold=True)
        title.setFrame_(NSMakeRect(PADDING, y, WIN_WIDTH - 2 * PADDING, 28))
        title.setTextColor_(LABEL_COLOR)
        content.addSubview_(title)

        y -= 16

        # ── Separator ──
        y -= 1
        content.addSubview_(self._separator(y))
        y -= 32

        # ── Hotkey ──
        content.addSubview_(
            self._positioned_label("Global Hotkey", PADDING, y, LABEL_W, 22)
        )
        self._hotkey_field = HotkeyField.alloc().initWithFrame_(
            NSMakeRect(CONTROL_X, y - 4, CONTROL_W, 30)
        )
        self._hotkey_field._on_change = self._hotkey_changed
        content.addSubview_(self._hotkey_field)

        y -= 22
        sub = self._make_label(
            "Click the field, then press your desired key combo", size=10, color=SUBLABEL_COLOR
        )
        sub.setFrame_(NSMakeRect(CONTROL_X, y, CONTROL_W, 16))
        content.addSubview_(sub)

        y -= 44

        # ── AI Cleanup toggle ──
        content.addSubview_(
            self._positioned_label("AI Cleanup", PADDING, y, LABEL_W, 22)
        )
        self._cleanup_toggle = NSButton.alloc().initWithFrame_(
            NSMakeRect(CONTROL_X, y, CONTROL_W, 22)
        )
        self._cleanup_toggle.setButtonType_(NSButtonTypeSwitch)
        self._cleanup_toggle.setTitle_("")
        self._cleanup_toggle.setAttributedTitle_(
            self._attributed_string("Clean up transcribed text with AI", 12, LABEL_COLOR)
        )
        self._cleanup_toggle.setTarget_(self._target)
        self._cleanup_toggle.setAction_(self._target.cleanupToggled_)
        content.addSubview_(self._cleanup_toggle)

        y -= 44

        # ── Cleanup style ──
        content.addSubview_(
            self._positioned_label("Cleanup Style", PADDING, y, LABEL_W, 22)
        )
        self._style_popup = NSPopUpButton.alloc().initWithFrame_pullsDown_(
            NSMakeRect(CONTROL_X, y - 2, CONTROL_W, 26), False
        )
        self._style_popup.setFont_(NSFont.systemFontOfSize_(12))
        for s in STYLES:
            self._style_popup.addItemWithTitle_(STYLE_LABELS[s])
        self._style_popup.setTarget_(self._target)
        self._style_popup.setAction_(self._target.styleChanged_)
        self._style_popup.setWantsLayer_(True)
        self._style_popup.layer().setCornerRadius_(6)
        content.addSubview_(self._style_popup)

        y -= 22
        self._style_desc = self._make_label("", size=10, color=SUBLABEL_COLOR)
        self._style_desc.setFrame_(NSMakeRect(CONTROL_X, y, CONTROL_W, 16))
        content.addSubview_(self._style_desc)

        y -= 52

        # ── Separator ──
        content.addSubview_(self._separator(y))
        y -= 36

        # ── Footer ──
        info = self._make_label(
            "Settings are saved automatically to\n~/Library/Application Support/Handy/",
            size=10, color=SUBLABEL_COLOR,
        )
        info.setFrame_(NSMakeRect(PADDING, y, WIN_WIDTH - 2 * PADDING, 28))
        content.addSubview_(info)

    # ── widget helpers ──

    def _make_label(self, text, size=13, bold=False, color=None):
        lbl = NSTextField.labelWithString_(text)
        lbl.setFont_(NSFont.boldSystemFontOfSize_(size) if bold else NSFont.systemFontOfSize_(size))
        lbl.setTextColor_(color or LABEL_COLOR)
        lbl.setBezeled_(False)
        lbl.setDrawsBackground_(False)
        lbl.setEditable_(False)
        lbl.setSelectable_(False)
        return lbl

    def _positioned_label(self, text, x, y, w, h, **kw):
        lbl = self._make_label(text, **kw)
        lbl.setFrame_(NSMakeRect(x, y, w, h))
        return lbl

    def _separator(self, y):
        sep = NSView.alloc().initWithFrame_(
            NSMakeRect(PADDING, y, WIN_WIDTH - 2 * PADDING, 1)
        )
        sep.setWantsLayer_(True)
        sep.layer().setBackgroundColor_(
            NSColor.colorWithCalibratedRed_green_blue_alpha_(0.3, 0.3, 0.35, 1.0).CGColor()
        )
        return sep

    def _attributed_string(self, text, size, color):
        attrs = {
            Cocoa.NSFontAttributeName: NSFont.systemFontOfSize_(size),
            Cocoa.NSForegroundColorAttributeName: color,
        }
        return Cocoa.NSAttributedString.alloc().initWithString_attributes_(text, attrs)

    # ── load / callbacks ──

    def _load_values(self):
        s = settings_mgr.load()
        self._hotkey_field.setHotkey_key_(s["hotkey_modifier"], s["hotkey_key"])
        self._cleanup_toggle.setState_(1 if s["cleanup_enabled"] else 0)
        idx = STYLES.index(s["cleanup_style"]) if s["cleanup_style"] in STYLES else 0
        self._style_popup.selectItemAtIndex_(idx)
        self._update_style_desc()
        self._update_style_enabled()

    def _hotkey_changed(self, modifier, key):
        settings_mgr.set("hotkey_modifier", modifier)
        settings_mgr.set("hotkey_key", key)
        self._notify()

    def _cleanup_toggled(self, sender):
        enabled = sender.state() == 1
        settings_mgr.set("cleanup_enabled", enabled)
        self._update_style_enabled()
        self._notify()

    def _style_changed(self, sender):
        idx = sender.indexOfSelectedItem()
        style = STYLES[idx] if idx < len(STYLES) else "casual"
        settings_mgr.set("cleanup_style", style)
        self._update_style_desc()
        self._notify()

    def _update_style_desc(self):
        idx = self._style_popup.indexOfSelectedItem()
        style = STYLES[idx] if idx < len(STYLES) else "casual"
        self._style_desc.setStringValue_(STYLE_DESCS.get(style, ""))

    def _update_style_enabled(self):
        enabled = self._cleanup_toggle.state() == 1
        self._style_popup.setEnabled_(enabled)

    def _notify(self):
        if self._on_settings_changed:
            self._on_settings_changed()
