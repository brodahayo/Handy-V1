"""Floating recording indicator — appears above the dock when recording.

Supports two visual styles:
  - Classic: Larger pill with full waveform bars
  - Mini: Compact dark capsule with small animated bars (like Vowen/Wispr)
"""

import objc
import math
import Cocoa
from AppKit import (
    NSPanel, NSView, NSColor, NSFont, NSBezierPath,
    NSWindowStyleMaskBorderless, NSWindowStyleMaskNonactivatingPanel,
    NSBackingStoreBuffered, NSFloatingWindowLevel,
    NSScreen, NSTimer, NSApplication,
    NSVisualEffectView, NSVisualEffectMaterialDark,
    NSVisualEffectBlendingModeBehindWindow, NSVisualEffectStateActive,
    NSTrackingArea, NSTrackingMouseEnteredAndExited, NSTrackingActiveAlways,
)
from Foundation import NSMakeRect, NSMakeSize
import settings as settings_mgr


# ── Mini Style ────────────────────────────────────────────────────────

MINI_WIDTH = 148
MINI_HEIGHT = 36
MINI_RADIUS = 18
MINI_BAR_COUNT = 7
MINI_BAR_WIDTH = 3.0
MINI_BAR_GAP = 4.0
MINI_BAR_MAX_H = 16.0
MINI_BAR_MIN_H = 4.0


class MiniWaveformView(NSView):
    """Animated waveform bars for the mini pill — driven by real mic audio level."""

    def initWithFrame_(self, frame):
        self = objc.super(MiniWaveformView, self).initWithFrame_(frame)
        if self is None:
            return None
        self._phase = 0.0
        self._timer = None
        self._animating = False
        self._level = 0.0          # current mic RMS (0.0–1.0)
        self._smooth_level = 0.0   # smoothed for display
        self._level_provider = None # callable returning float 0.0–1.0
        return self

    def drawRect_(self, rect):
        cx = self.bounds().size.width / 2
        cy = self.bounds().size.height / 2
        total_w = MINI_BAR_COUNT * MINI_BAR_WIDTH + (MINI_BAR_COUNT - 1) * MINI_BAR_GAP
        lv = self._smooth_level

        for i in range(MINI_BAR_COUNT):
            x = cx - total_w / 2 + i * (MINI_BAR_WIDTH + MINI_BAR_GAP)
            center_factor = 1.0 - abs(i - MINI_BAR_COUNT / 2.0) / (MINI_BAR_COUNT / 2.0) * 0.4
            wave = abs(math.sin(self._phase + i * 0.7))
            # Gentle idle sway (0.25) + voice-driven boost on top
            idle = 0.25 * wave * center_factor
            voice = lv * center_factor * (0.5 + 0.5 * wave)
            h = MINI_BAR_MIN_H + (MINI_BAR_MAX_H - MINI_BAR_MIN_H) * max(idle, voice)
            y = cy - h / 2

            bar = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
                NSMakeRect(x, y, MINI_BAR_WIDTH, h),
                MINI_BAR_WIDTH / 2, MINI_BAR_WIDTH / 2
            )
            alpha = 0.6 + 0.4 * max(idle, voice)
            NSColor.colorWithWhite_alpha_(1.0, alpha).setFill()
            bar.fill()

    def startAnimating(self):
        if self._animating:
            return
        self._animating = True
        self._timer = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
            0.04, self, objc.selector(self.tick_, signature=b'v@:@'), None, True
        )

    def stopAnimating(self):
        self._animating = False
        if self._timer:
            self._timer.invalidate()
            self._timer = None

    @objc.typedSelector(b'v@:@')
    def tick_(self, timer):
        self._phase += 0.18
        # Read live mic level
        if self._level_provider:
            try:
                self._level = float(self._level_provider())
            except Exception:
                self._level = 0.0
        # Smooth for display (fast attack, slower decay)
        target = self._level
        if target > self._smooth_level:
            self._smooth_level += (target - self._smooth_level) * 0.5
        else:
            self._smooth_level += (target - self._smooth_level) * 0.15
        self.setNeedsDisplay_(True)


# ── Classic Style ─────────────────────────────────────────────────────

CLASSIC_WIDTH = 200
CLASSIC_HEIGHT = 48
CLASSIC_RADIUS = 24
CLASSIC_BAR_COUNT = 9
CLASSIC_BAR_WIDTH = 3.5
CLASSIC_BAR_GAP = 4.5
CLASSIC_BAR_MAX_H = 22.0
CLASSIC_BAR_MIN_H = 5.0


class ClassicWaveformView(NSView):
    """Animated waveform bars for the classic pill — driven by real mic audio level."""

    def initWithFrame_(self, frame):
        self = objc.super(ClassicWaveformView, self).initWithFrame_(frame)
        if self is None:
            return None
        self._phase = 0.0
        self._timer = None
        self._animating = False
        self._level = 0.0
        self._smooth_level = 0.0
        self._level_provider = None
        return self

    def drawRect_(self, rect):
        cx = self.bounds().size.width / 2
        cy = self.bounds().size.height / 2
        total_w = CLASSIC_BAR_COUNT * CLASSIC_BAR_WIDTH + (CLASSIC_BAR_COUNT - 1) * CLASSIC_BAR_GAP
        lv = self._smooth_level

        for i in range(CLASSIC_BAR_COUNT):
            x = cx - total_w / 2 + i * (CLASSIC_BAR_WIDTH + CLASSIC_BAR_GAP)
            center_factor = 1.0 - abs(i - CLASSIC_BAR_COUNT / 2.0) / (CLASSIC_BAR_COUNT / 2.0) * 0.35
            wave = abs(math.sin(self._phase + i * 0.6))
            idle = 0.25 * wave * center_factor
            voice = lv * center_factor * (0.5 + 0.5 * wave)
            h = CLASSIC_BAR_MIN_H + (CLASSIC_BAR_MAX_H - CLASSIC_BAR_MIN_H) * max(idle, voice)
            y = cy - h / 2

            bar = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
                NSMakeRect(x, y, CLASSIC_BAR_WIDTH, h),
                CLASSIC_BAR_WIDTH / 2, CLASSIC_BAR_WIDTH / 2
            )
            alpha = 0.5 + 0.5 * max(idle, voice)
            NSColor.colorWithWhite_alpha_(1.0, alpha).setFill()
            bar.fill()

    def startAnimating(self):
        if self._animating:
            return
        self._animating = True
        self._timer = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
            0.04, self, objc.selector(self.tick_, signature=b'v@:@'), None, True
        )

    def stopAnimating(self):
        self._animating = False
        if self._timer:
            self._timer.invalidate()
            self._timer = None

    @objc.typedSelector(b'v@:@')
    def tick_(self, timer):
        self._phase += 0.14
        if self._level_provider:
            try:
                self._level = float(self._level_provider())
            except Exception:
                self._level = 0.0
        target = self._level
        if target > self._smooth_level:
            self._smooth_level += (target - self._smooth_level) * 0.5
        else:
            self._smooth_level += (target - self._smooth_level) * 0.15
        self.setNeedsDisplay_(True)


# ── Stop Button ───────────────────────────────────────────────────────

class StopButton(NSView):
    """Small stop button (white square on red circle)."""

    def initWithFrame_(self, frame):
        self = objc.super(StopButton, self).initWithFrame_(frame)
        if self is None:
            return None
        self._on_click = None
        self._hovered = False

        area = NSTrackingArea.alloc().initWithRect_options_owner_userInfo_(
            self.bounds(),
            NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways,
            self, None
        )
        self.addTrackingArea_(area)
        return self

    def drawRect_(self, rect):
        w = self.bounds().size.width
        h = self.bounds().size.height

        circle = NSBezierPath.bezierPathWithOvalInRect_(NSMakeRect(0, 0, w, h))
        if self._hovered:
            NSColor.colorWithCalibratedRed_green_blue_alpha_(0.95, 0.25, 0.25, 1.0).setFill()
        else:
            NSColor.colorWithCalibratedRed_green_blue_alpha_(0.85, 0.18, 0.18, 1.0).setFill()
        circle.fill()

        inset = w * 0.3
        sq = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
            NSMakeRect(inset, inset, w - inset * 2, h - inset * 2), 2, 2
        )
        NSColor.whiteColor().setFill()
        sq.fill()

    def mouseEntered_(self, event):
        self._hovered = True
        self.setNeedsDisplay_(True)

    def mouseExited_(self, event):
        self._hovered = False
        self.setNeedsDisplay_(True)

    def mouseDown_(self, event):
        if self._on_click:
            self._on_click()

    def acceptsFirstMouse_(self, event):
        return True


# ── Recording Overlay Manager ─────────────────────────────────────────

class RecordingOverlay:
    """Manages the floating recording pill window. Supports Classic, Mini, and None styles."""

    def __init__(self, on_stop=None, level_provider=None):
        self._on_stop = on_stop
        self._level_provider = level_provider  # callable returning float 0.0–1.0
        self._panel = None
        self._waveform = None
        self._style = None
        self._built = False

    def _build(self, style):
        # Always rebuild to pick up position/style changes
        if self._panel:
            self._panel.orderOut_(None)
            self._panel = None
            self._waveform = None
            self._built = False

        if style == "mini":
            self._build_mini()
        else:
            self._build_classic()

        self._style = style
        self._built = True

    def _get_position(self, width, height):
        """Get overlay position from settings."""
        screen = NSScreen.mainScreen().frame()
        pos = settings_mgr.get("overlay_position") or "bottom-center"
        if pos == "top-center":
            x = (screen.size.width - width) / 2
            y = screen.size.height - height - 80
        elif pos == "top-left":
            x = 40
            y = screen.size.height - height - 80
        elif pos == "top-right":
            x = screen.size.width - width - 40
            y = screen.size.height - height - 80
        elif pos == "bottom-left":
            x = 40
            y = 80
        elif pos == "bottom-right":
            x = screen.size.width - width - 40
            y = 80
        else:  # bottom-center (default)
            x = (screen.size.width - width) / 2
            y = 80
        return x, y

    def _build_mini(self):
        """Build the compact mini pill."""
        x, y = self._get_position(MINI_WIDTH, MINI_HEIGHT)

        rect = NSMakeRect(x, y, MINI_WIDTH, MINI_HEIGHT)
        self._panel = self._create_panel(rect)

        content = NSView.alloc().initWithFrame_(NSMakeRect(0, 0, MINI_WIDTH, MINI_HEIGHT))
        content.setWantsLayer_(True)
        content.layer().setCornerRadius_(MINI_RADIUS)
        content.layer().setMasksToBounds_(True)

        # Dark background
        bg = NSView.alloc().initWithFrame_(NSMakeRect(0, 0, MINI_WIDTH, MINI_HEIGHT))
        bg.setWantsLayer_(True)
        bg.layer().setBackgroundColor_(
            NSColor.colorWithCalibratedRed_green_blue_alpha_(0.08, 0.08, 0.12, 0.92).CGColor()
        )
        content.addSubview_(bg)

        # Waveform (left-center area, leaving room for stop button)
        waveform_w = MINI_BAR_COUNT * (MINI_BAR_WIDTH + MINI_BAR_GAP) + 10
        self._waveform = MiniWaveformView.alloc().initWithFrame_(
            NSMakeRect(12, 0, waveform_w, MINI_HEIGHT)
        )
        self._waveform._level_provider = self._level_provider
        content.addSubview_(self._waveform)

        # Stop button (right side)
        btn_size = 22
        stop = StopButton.alloc().initWithFrame_(
            NSMakeRect(
                MINI_WIDTH - btn_size - 10,
                (MINI_HEIGHT - btn_size) / 2,
                btn_size, btn_size
            )
        )
        stop._on_click = self._stop_clicked
        content.addSubview_(stop)

        self._panel.setContentView_(content)

    def _build_classic(self):
        """Build the larger classic pill with stop button."""
        x, y = self._get_position(CLASSIC_WIDTH, CLASSIC_HEIGHT)

        rect = NSMakeRect(x, y, CLASSIC_WIDTH, CLASSIC_HEIGHT)
        self._panel = self._create_panel(rect)

        content = NSView.alloc().initWithFrame_(NSMakeRect(0, 0, CLASSIC_WIDTH, CLASSIC_HEIGHT))
        content.setWantsLayer_(True)
        content.layer().setCornerRadius_(CLASSIC_RADIUS)
        content.layer().setMasksToBounds_(True)

        # Vibrancy background
        vibrancy = NSVisualEffectView.alloc().initWithFrame_(
            NSMakeRect(0, 0, CLASSIC_WIDTH, CLASSIC_HEIGHT)
        )
        vibrancy.setMaterial_(NSVisualEffectMaterialDark)
        vibrancy.setBlendingMode_(NSVisualEffectBlendingModeBehindWindow)
        vibrancy.setState_(NSVisualEffectStateActive)
        content.addSubview_(vibrancy)

        # Dark overlay
        dark = NSView.alloc().initWithFrame_(NSMakeRect(0, 0, CLASSIC_WIDTH, CLASSIC_HEIGHT))
        dark.setWantsLayer_(True)
        dark.layer().setBackgroundColor_(
            NSColor.colorWithCalibratedRed_green_blue_alpha_(0.06, 0.06, 0.1, 0.75).CGColor()
        )
        content.addSubview_(dark)

        # Waveform (center-left area)
        waveform_w = CLASSIC_BAR_COUNT * (CLASSIC_BAR_WIDTH + CLASSIC_BAR_GAP) + 10
        self._waveform = ClassicWaveformView.alloc().initWithFrame_(
            NSMakeRect(16, 0, waveform_w, CLASSIC_HEIGHT)
        )
        self._waveform._level_provider = self._level_provider
        content.addSubview_(self._waveform)

        # Stop button (right side)
        btn_size = 30
        stop = StopButton.alloc().initWithFrame_(
            NSMakeRect(
                CLASSIC_WIDTH - btn_size - 10,
                (CLASSIC_HEIGHT - btn_size) / 2,
                btn_size, btn_size
            )
        )
        stop._on_click = self._stop_clicked
        content.addSubview_(stop)

        self._panel.setContentView_(content)

    def _create_panel(self, rect):
        """Create the shared NSPanel with common properties."""
        panel = NSPanel.alloc().initWithContentRect_styleMask_backing_defer_(
            rect,
            NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel,
            NSBackingStoreBuffered,
            False,
        )
        panel.setLevel_(NSFloatingWindowLevel + 2)
        panel.setOpaque_(False)
        panel.setBackgroundColor_(NSColor.clearColor())
        panel.setHasShadow_(True)
        panel.setMovableByWindowBackground_(True)
        panel.setCollectionBehavior_(
            1 << 0 | 1 << 4  # canJoinAllSpaces | fullScreenAuxiliary
        )
        return panel

    def show(self):
        """Show the recording pill with animation."""
        style = settings_mgr.get("overlay_style") or "mini"
        if style == "none":
            return

        self._build(style)
        self._waveform.startAnimating()
        self._panel.setAlphaValue_(0.0)
        self._panel.orderFront_(None)

        Cocoa.NSAnimationContext.beginGrouping()
        Cocoa.NSAnimationContext.currentContext().setDuration_(0.2)
        self._panel.animator().setAlphaValue_(1.0)
        Cocoa.NSAnimationContext.endGrouping()

    def hide(self):
        """Hide the recording pill with animation."""
        if not self._panel:
            return
        if self._waveform:
            self._waveform.stopAnimating()

        Cocoa.NSAnimationContext.beginGrouping()
        Cocoa.NSAnimationContext.currentContext().setDuration_(0.15)
        self._panel.animator().setAlphaValue_(0.0)
        Cocoa.NSAnimationContext.endGrouping()

        NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
            0.2, self._panel, objc.selector(None, selector=b'orderOut:', signature=b'v@:@'),
            self._panel, False
        )

    def _stop_clicked(self):
        if self._on_stop:
            self._on_stop()
        self.hide()
