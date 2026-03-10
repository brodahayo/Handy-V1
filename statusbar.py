"""
macOS menu bar status item for Handy using raw PyObjC.
Do NOT use rumps — it conflicts with pywebview.
"""

import objc
from AppKit import (
    NSStatusBar,
    NSVariableStatusItemLength,
    NSMenu,
    NSMenuItem,
    NSImage,
    NSApp,
)
from PyObjCTools import AppHelper


class StatusBarController:
    """Controls the macOS menu bar status item for Handy."""

    def __init__(self, on_toggle, on_open, on_quit):
        """Store callbacks for menu actions.

        Args:
            on_toggle: Called when "Toggle Recording" is clicked.
            on_open: Called when "Open Handy" is clicked.
            on_quit: Called when "Quit Handy" is clicked.
        """
        self._on_toggle = on_toggle
        self._on_open = on_open
        self._on_quit = on_quit
        self._status_item = None
        self._is_recording = False

    def setup(self):
        """Create the NSStatusItem and menu. Must be called on the main thread."""
        self._status_item = NSStatusBar.systemStatusBar().statusItemWithLength_(
            NSVariableStatusItemLength
        )

        self._set_icon("mic.fill")

        menu = NSMenu.alloc().init()

        toggle_item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Toggle Recording", "toggleRecording:", ""
        )
        toggle_item.setTarget_(self)

        open_item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Open Handy", "openApp:", ""
        )
        open_item.setTarget_(self)

        separator = NSMenuItem.separatorItem()

        quit_item = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Quit Handy", "quitApp:", ""
        )
        quit_item.setTarget_(self)

        menu.addItem_(toggle_item)
        menu.addItem_(open_item)
        menu.addItem_(separator)
        menu.addItem_(quit_item)

        self._status_item.setMenu_(menu)

    def set_recording(self, is_recording):
        """Update the icon based on recording state. Must be called on the main thread.

        Args:
            is_recording: True to show active mic icon, False for idle.
        """
        self._is_recording = is_recording
        symbol_name = "mic.fill" if is_recording else "mic"
        self._set_icon(symbol_name)

    def _set_icon(self, symbol_name):
        """Set the status item icon using an SF Symbol.

        Args:
            symbol_name: SF Symbols name (e.g. "mic.fill", "mic").
        """
        image = NSImage.imageWithSystemSymbolName_accessibilityDescription_(
            symbol_name, "Handy"
        )
        if image is not None:
            image.setTemplate_(True)
            image.setSize_((18, 18))
        button = self._status_item.button()
        if button is not None:
            button.setImage_(image)

    @objc.typedSelector(b"v@:@")
    def toggleRecording_(self, sender):
        """Handle Toggle Recording menu action."""
        if self._on_toggle:
            self._on_toggle()

    @objc.typedSelector(b"v@:@")
    def openApp_(self, sender):
        """Handle Open Handy menu action."""
        if self._on_open:
            self._on_open()

    @objc.typedSelector(b"v@:@")
    def quitApp_(self, sender):
        """Handle Quit Handy menu action."""
        if self._on_quit:
            self._on_quit()

    def schedule_setup(self):
        """Schedule setup() on the main thread from a background thread."""
        AppHelper.callAfter(self.setup)

    def schedule_set_recording(self, is_recording):
        """Schedule set_recording() on the main thread from a background thread."""
        AppHelper.callAfter(self.set_recording, is_recording)
