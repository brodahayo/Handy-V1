# Hotkey Power Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add power icon buttons to each hotkey card that let users independently enable/disable Hold to Dictate and Toggle Recording, with confirmation dialogs on every toggle action.

**Architecture:** Two new booleans (`holdToDictateEnabled`, `toggleRecordingEnabled`) in `AppSettings` control whether each hotkey's event monitors are installed. The `HotkeySettingsView` gets power buttons with `.alert` confirmation dialogs. `HotkeyManager.configure()` gains enable flags and skips monitor installation for disabled hotkeys.

**Tech Stack:** SwiftUI, AppKit (NSEvent monitors), Swift `@Observable`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `Handy/Handy/Models/Settings.swift` | Modify | Add `holdToDictateEnabled` and `toggleRecordingEnabled` to `AppSettings` |
| `Handy/Handy/Services/HotkeyManager.swift` | Modify | Accept enable flags in `configure()`, skip monitors for disabled hotkeys |
| `Handy/Handy/Views/HotkeySettingsView.swift` | Modify | Add power buttons, disabled state, confirmation dialogs |
| `Handy/Handy/HandyApp.swift` | Modify | Pass enable flags to `configure()`, observe changes to new settings |
| `Handy/HandyTests/SettingsTests.swift` | Modify | Test new defaults and encode/decode |
| `Handy/HandyTests/SettingsPersistenceTests.swift` | Modify | Test persistence of new fields |

---

### Task 1: Add Enable Flags to AppSettings

**Files:**
- Modify: `Handy/Handy/Models/Settings.swift:107-132`
- Modify: `Handy/HandyTests/SettingsTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `SettingsTests.swift`:

```swift
func testDefaultHotkeyEnableFlags() {
    let settings = AppSettings()
    XCTAssertTrue(settings.holdToDictateEnabled)
    XCTAssertTrue(settings.toggleRecordingEnabled)
}

func testHotkeyEnableFlagsEncodeDecode() throws {
    var settings = AppSettings()
    settings.holdToDictateEnabled = false
    settings.toggleRecordingEnabled = false

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

    XCTAssertFalse(decoded.holdToDictateEnabled)
    XCTAssertFalse(decoded.toggleRecordingEnabled)
}

func testBackwardCompatibility_missingEnableFlags() throws {
    // Simulate old settings JSON without the new fields
    let oldJSON = """
    {"holdKey":"fn","toggleModifier":"option","toggleKey":"v","cloudProvider":"groq",
     "language":"auto","transcriptionMode":"cloud","localModelSize":"base",
     "cleanupEnabled":true,"cleanupStyle":"casual","contextAware":true,
     "overlayStyle":"mini","overlayPosition":"bottom_center",
     "soundEnabled":true,"soundPack":"droplet","launchAtLogin":false,
     "dailyGoal":500,"appearanceMode":"dark","hotkeyMode":"hold_fn"}
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AppSettings.self, from: oldJSON)
    XCTAssertTrue(decoded.holdToDictateEnabled)
    XCTAssertTrue(decoded.toggleRecordingEnabled)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Handy/Handy.xcodeproj -scheme Handy -testPlan HandyTests -only-testing HandyTests/SettingsTests 2>&1 | tail -20`
Expected: Compile error — `holdToDictateEnabled` and `toggleRecordingEnabled` not found

- [ ] **Step 3: Add the new properties to AppSettings**

In `Settings.swift`, add these two lines inside the `AppSettings` struct, after the `toggleKey` property (line 113):

```swift
var holdToDictateEnabled: Bool = true
var toggleRecordingEnabled: Bool = true
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Handy/Handy.xcodeproj -scheme Handy -testPlan HandyTests -only-testing HandyTests/SettingsTests 2>&1 | tail -20`
Expected: All tests PASS (backward compat works because `Codable` defaults fill missing keys)

- [ ] **Step 5: Commit**

```bash
git add Handy/Handy/Models/Settings.swift Handy/HandyTests/SettingsTests.swift
git commit -m "feat: add holdToDictateEnabled and toggleRecordingEnabled to AppSettings"
```

---

### Task 2: Update HotkeyManager to Accept Enable Flags

**Files:**
- Modify: `Handy/Handy/Services/HotkeyManager.swift:18-34`

- [ ] **Step 1: Update configure() signature and logic**

Replace the existing `configure` method in `HotkeyManager.swift`:

```swift
/// Configure both Quick Dictation (hold) and Hands-Free (toggle) simultaneously.
/// Pass `holdEnabled: false` or `toggleEnabled: false` to skip installing those monitors.
func configure(holdKey: HoldKey, toggleModifier: String, toggleKey: String,
               holdEnabled: Bool = true, toggleEnabled: Bool = true) {
    tearDown()

    print("[Handy] Configuring hotkeys — holdKey: \(holdKey), toggle: \(toggleModifier)+\(toggleKey), holdEnabled: \(holdEnabled), toggleEnabled: \(toggleEnabled)")

    if holdEnabled {
        if holdKey == .fn {
            installFnHoldMonitor()
        } else {
            installModifierHoldMonitor(holdKey: holdKey)
        }
    }

    if toggleEnabled {
        installToggleMonitor(modifier: toggleModifier, key: toggleKey)
    }

    print("[Handy] Hotkey configured — \(monitors.count) monitors active")
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project Handy/Handy.xcodeproj -scheme Handy 2>&1 | tail -10`
Expected: BUILD SUCCEEDED (existing callers still work because of default parameter values)

- [ ] **Step 3: Commit**

```bash
git add Handy/Handy/Services/HotkeyManager.swift
git commit -m "feat: add holdEnabled/toggleEnabled flags to HotkeyManager.configure()"
```

---

### Task 3: Wire Enable Flags Through HandyApp

**Files:**
- Modify: `Handy/Handy/HandyApp.swift:248-272` (configureHotkeys method)
- Modify: `Handy/Handy/HandyApp.swift:52-54` (onChange observers)

- [ ] **Step 1: Update configureHotkeys() to pass enable flags**

In `HandyApp.swift`, update the `configureHotkeys()` method. Replace the `hotkeyManager.configure(` call at lines 266-270:

```swift
hotkeyManager.configure(
    holdKey: appState.settings.holdKey,
    toggleModifier: appState.settings.toggleModifier,
    toggleKey: appState.settings.toggleKey,
    holdEnabled: appState.settings.holdToDictateEnabled,
    toggleEnabled: appState.settings.toggleRecordingEnabled
)
```

- [ ] **Step 2: Also update the accessibility polling reconfigure call**

In `startAccessibilityPolling()`, update the `hotkeyManager.configure(` call around line 295:

```swift
hotkeyManager.configure(
    holdKey: appState.settings.holdKey,
    toggleModifier: appState.settings.toggleModifier,
    toggleKey: appState.settings.toggleKey,
    holdEnabled: appState.settings.holdToDictateEnabled,
    toggleEnabled: appState.settings.toggleRecordingEnabled
)
```

- [ ] **Step 3: Add onChange observers for the new settings**

In `HandyApp.swift`, after the existing `.onChange(of: appState.settings.toggleKey)` line (around line 54), add:

```swift
.onChange(of: appState.settings.holdToDictateEnabled) { configureHotkeys() }
.onChange(of: appState.settings.toggleRecordingEnabled) { configureHotkeys() }
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild build -project Handy/Handy.xcodeproj -scheme Handy 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Handy/Handy/HandyApp.swift
git commit -m "feat: wire hotkey enable flags through HandyApp.configureHotkeys()"
```

---

### Task 4: Add Power Buttons and Confirmation Dialogs to HotkeySettingsView

**Files:**
- Modify: `Handy/Handy/Views/HotkeySettingsView.swift`

- [ ] **Step 1: Add state properties for confirmation alerts**

At the top of `HotkeySettingsView`, after the existing `@State` property, add:

```swift
@State private var showHoldToggleAlert = false
@State private var showToggleRecordingAlert = false
```

- [ ] **Step 2: Replace the "Quick Dictation" section**

Replace the existing `Section("Quick Dictation")` block (lines 9-21) with:

```swift
Section {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick Dictation")
                .font(.headline)
            Text("Hold to record, release to transcribe.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
            showHoldToggleAlert = true
        } label: {
            Image(systemName: "power")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(appState.settings.holdToDictateEnabled ? Color.purple : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(appState.settings.holdToDictateEnabled
                              ? Color.purple.opacity(0.15)
                              : Color.secondary.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .stroke(appState.settings.holdToDictateEnabled
                                ? Color.purple.opacity(0.3)
                                : Color.secondary.opacity(0.15), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .alert(
            appState.settings.holdToDictateEnabled ? "Disable Hold to Dictate?" : "Enable Hold to Dictate?",
            isPresented: $showHoldToggleAlert
        ) {
            Button("Cancel", role: .cancel) { }
            if appState.settings.holdToDictateEnabled {
                Button("Disable", role: .destructive) {
                    appState.settings.holdToDictateEnabled = false
                }
            } else {
                Button("Enable") {
                    appState.settings.holdToDictateEnabled = true
                }
            }
        } message: {
            if appState.settings.holdToDictateEnabled {
                Text("The \(appState.settings.holdKey == .fn ? "Fn" : appState.settings.holdKey.rawValue) key will stop responding until you re-enable it.")
            } else {
                Text("The \(appState.settings.holdKey == .fn ? "Fn" : appState.settings.holdKey.rawValue) key will start responding to key presses again.")
            }
        }
    }

    Picker("Hold Key", selection: $appState.settings.holdKey) {
        Text("Fn (Globe)").tag(HoldKey.fn)
        Text("Option (⌥)").tag(HoldKey.option)
        Text("Option + Shift (⌥⇧)").tag(HoldKey.optionShift)
        Text("Command (⌘)").tag(HoldKey.command)
        Text("Control (⌃)").tag(HoldKey.control)
    }
    .disabled(!appState.settings.holdToDictateEnabled)
    .opacity(appState.settings.holdToDictateEnabled ? 1.0 : 0.35)
}
```

- [ ] **Step 3: Replace the "Hands-Free Shortcut" section**

Replace the existing `Section("Hands-Free Shortcut")` block (lines 23-47) with:

```swift
Section {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hands-Free Shortcut")
                .font(.headline)
            Text("Press to start, press again to stop.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
            showToggleRecordingAlert = true
        } label: {
            Image(systemName: "power")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(appState.settings.toggleRecordingEnabled ? Color.purple : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(appState.settings.toggleRecordingEnabled
                              ? Color.purple.opacity(0.15)
                              : Color.secondary.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .stroke(appState.settings.toggleRecordingEnabled
                                ? Color.purple.opacity(0.3)
                                : Color.secondary.opacity(0.15), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .alert(
            appState.settings.toggleRecordingEnabled ? "Disable Toggle Recording?" : "Enable Toggle Recording?",
            isPresented: $showToggleRecordingAlert
        ) {
            Button("Cancel", role: .cancel) { }
            if appState.settings.toggleRecordingEnabled {
                Button("Disable", role: .destructive) {
                    appState.settings.toggleRecordingEnabled = false
                }
            } else {
                Button("Enable") {
                    appState.settings.toggleRecordingEnabled = true
                }
            }
        } message: {
            if appState.settings.toggleRecordingEnabled {
                Text("The \(appState.settings.toggleModifier)+\(appState.settings.toggleKey.uppercased()) shortcut will stop responding until you re-enable it.")
            } else {
                Text("The \(appState.settings.toggleModifier)+\(appState.settings.toggleKey.uppercased()) shortcut will start responding to key presses again.")
            }
        }
    }

    HStack {
        Picker("Modifier", selection: $appState.settings.toggleModifier) {
            Text("⌥ Option").tag("option")
            Text("⌘ Command").tag("command")
            Text("⌃ Control").tag("control")
        }
        .frame(width: 150)

        Text("+")

        Picker("Key", selection: $appState.settings.toggleKey) {
            Text("V").tag("v")
            Text("D").tag("d")
            Text("R").tag("r")
            Text("T").tag("t")
            Text("Space").tag("space")
        }
        .frame(width: 100)
    }
    .disabled(!appState.settings.toggleRecordingEnabled)
    .opacity(appState.settings.toggleRecordingEnabled ? 1.0 : 0.35)
}
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild build -project Handy/Handy.xcodeproj -scheme Handy 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Handy/Handy/Views/HotkeySettingsView.swift
git commit -m "feat: add power toggle buttons with confirmation dialogs to hotkey settings"
```

---

### Task 5: Persistence Tests and Final Verification

**Files:**
- Modify: `Handy/HandyTests/SettingsPersistenceTests.swift`

- [ ] **Step 1: Add persistence test for enable flags**

Add to `SettingsPersistenceTests.swift`:

```swift
func testSaveAndLoadHotkeyEnableFlags() throws {
    let persistence = SettingsPersistence(directory: testDir)
    var settings = AppSettings()
    settings.holdToDictateEnabled = false
    settings.toggleRecordingEnabled = false

    try persistence.save(settings)
    let loaded = try persistence.load()

    XCTAssertFalse(loaded.holdToDictateEnabled)
    XCTAssertFalse(loaded.toggleRecordingEnabled)
}
```

- [ ] **Step 2: Run the full test suite**

Run: `xcodebuild test -project Handy/Handy.xcodeproj -scheme Handy -testPlan HandyTests 2>&1 | tail -30`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add Handy/HandyTests/SettingsPersistenceTests.swift
git commit -m "test: add persistence tests for hotkey enable flags"
```

- [ ] **Step 4: Final build verification**

Run: `xcodebuild build -project Handy/Handy.xcodeproj -scheme Handy 2>&1 | tail -10`
Expected: BUILD SUCCEEDED
