# Hotkey Power Toggle — Design Spec

**Date:** 2026-03-31
**Design:** F — Power Icon Button with Confirmation Dialogs

## Summary

Add the ability to independently enable/disable the Hold to Dictate and Toggle Recording hotkeys via a circular power icon button in the top-right corner of each hotkey card, with confirmation dialogs for both enable and disable actions.

## UI Changes

### Power Button
- Circular, 26px, positioned absolutely at top-right (12px inset) of each hotkey card
- **Enabled state:** Purple-tinted background (`rgba(180,140,240,0.12)`), purple border (`rgba(180,140,240,0.3)`), purple stroke icon
- **Disabled state:** Near-transparent background (`rgba(255,255,255,0.03)`), subtle border (`rgba(255,255,255,0.08)`), gray stroke icon
- Uses standard power icon (line + arc SVG)

### Card Disabled State
- Entire card dims to ~30% opacity
- Pickers remain visible (dimmed) but become non-interactive
- User's key configuration is preserved — re-enabling restores their previous settings

### Confirmation Dialogs
Shown on **every** toggle action (both enable and disable):

**Disable dialog:**
- Muted red icon tint and button color
- Title: "Disable {Hotkey Name}?"
- Description: "The {key binding} shortcut will stop responding until you re-enable it."
- Buttons: Cancel | Disable

**Enable dialog:**
- Purple icon tint and button color
- Title: "Enable {Hotkey Name}?"
- Description: "The {key binding} shortcut will start responding to key presses again."
- Buttons: Cancel | Enable

Dialog text dynamically references the hotkey name ("Hold to Dictate" or "Toggle Recording") and the current key binding (e.g., "Fn", "⌥V").

## Data Model Changes

Add two new boolean properties to `AppSettings`:

```swift
var holdToDictateEnabled: Bool = true
var toggleRecordingEnabled: Bool = true
```

Defaults to `true` for backward compatibility — existing users see no change.

## Files to Modify

1. **`Settings.swift`** — Add `holdToDictateEnabled` and `toggleRecordingEnabled` to `AppSettings`
2. **`HotkeySettingsView.swift`** — Add power buttons to each card section, add confirmation alert, dim/disable pickers when off
3. **`HotkeyManager.swift`** — Update `configure()` to accept enable flags; skip installing monitors for disabled hotkeys
4. **`AppState.swift`** or wherever `configure()` is called — Pass the new enable flags when configuring hotkeys

## Behavior Rules

- Both hotkeys default to enabled
- Clicking power button always shows confirmation before toggling
- Disabled hotkeys do not install event monitors (no system resource usage)
- Pickers are visible but non-interactive when disabled
- Settings persist across app restarts via existing `SettingsPersistence`
- Re-enabling restores the user's previously configured key bindings
