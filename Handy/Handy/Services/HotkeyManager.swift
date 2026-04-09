import Cocoa

final class HotkeyManager: @unchecked Sendable {
    var onRecordingStart: (@Sendable () -> Void)?
    var onRecordingStop: (@Sendable () -> Void)?

    /// When true, all hotkey monitors ignore events (used during key recording).
    var isPaused = false

    private var monitors: [Any] = []
    private var isKeyHeld = false
    private var isToggleActive = false
    private var watchdogTimer: Timer?
    private var lastEventTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.15

    var isConfigured: Bool { !monitors.isEmpty }

    /// 65535 means modifier-only hold; any other value means a regular key hold.
    static let modifierOnlyKeyCode: UInt16 = 65535

    /// Configure both Quick Dictation (hold) and Hands-Free (toggle) simultaneously
    /// using raw modifier flags and key codes.
    func configure(holdKeyCode: UInt16, holdModifierFlags: UInt,
                   toggleKeyCode: UInt16, toggleModifierFlags: UInt,
                   holdEnabled: Bool = true, toggleEnabled: Bool = true) {
        tearDown()

        let holdDisplay = holdKeyCode == Self.modifierOnlyKeyCode
            ? Self.displayName(forModifierFlags: holdModifierFlags)
            : Self.displayName(forModifierFlags: holdModifierFlags) + Self.displayName(forKeyCode: holdKeyCode)
        let toggleDisplay = Self.displayName(forModifierFlags: toggleModifierFlags) + Self.displayName(forKeyCode: toggleKeyCode)
        print("[Handy] Configuring hotkeys — hold: \(holdDisplay), toggle: \(toggleDisplay), holdEnabled: \(holdEnabled), toggleEnabled: \(toggleEnabled)")

        if holdEnabled {
            if holdKeyCode == Self.modifierOnlyKeyCode {
                // Modifier-only hold (e.g. Fn, Option)
                installHoldMonitor(flags: NSEvent.ModifierFlags(rawValue: holdModifierFlags))
            } else {
                // Regular key hold (e.g. hold "A")
                installKeyHoldMonitor(keyCode: holdKeyCode, modifierFlags: NSEvent.ModifierFlags(rawValue: holdModifierFlags))
            }
        }

        if toggleEnabled {
            installToggleMonitor(keyCode: toggleKeyCode, modifierFlags: NSEvent.ModifierFlags(rawValue: toggleModifierFlags))
        }

        print("[Handy] Hotkey configured — \(monitors.count) monitors active")
    }

    /// Check whether the app has accessibility permissions.
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility permissions prompt from the system.
    static func requestAccessibilityPermissions() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("[Handy] Accessibility trusted: \(trusted)")
    }

    func tearDown() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        isKeyHeld = false
        isToggleActive = false
    }

    // MARK: - Hold Modifier Key (unified for all modifiers including Fn)

    private func installHoldMonitor(flags targetFlags: NSEvent.ModifierFlags) {
        let handler: (NSEvent) -> Bool = { [weak self] event in
            guard let self, !self.isPaused, !self.isToggleActive else { return false }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastEventTime > self.debounceInterval else { return false }

            let pressed = event.modifierFlags.contains(targetFlags)

            if pressed && !self.isKeyHeld {
                self.isKeyHeld = true
                self.lastEventTime = now
                print("[Handy] Hold key pressed — starting recording")
                self.onRecordingStart?()
                self.startWatchdog(flags: targetFlags)
                return true
            } else if !pressed && self.isKeyHeld {
                self.isKeyHeld = false
                self.lastEventTime = now
                print("[Handy] Hold key released — stopping recording")
                self.onRecordingStop?()
                self.watchdogTimer?.invalidate()
                return true
            }
            return false
        }

        let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            _ = handler(event)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event) ? nil : event
        }
        if let global { monitors.append(global) }
        if let local { monitors.append(local) }
    }

    // MARK: - Regular Key Hold (e.g. hold "A" to dictate)

    private func installKeyHoldMonitor(keyCode targetKeyCode: UInt16, modifierFlags targetModifier: NSEvent.ModifierFlags) {
        let keyDownHandler: (NSEvent) -> Bool = { [weak self] event in
            guard let self, !self.isPaused, !self.isToggleActive else { return false }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastEventTime > self.debounceInterval else { return false }

            // Check for matching key + modifiers (if any required)
            let eventMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let modMatch = targetModifier.isEmpty || eventMods.contains(targetModifier)

            if event.keyCode == targetKeyCode && modMatch && !self.isKeyHeld {
                self.isKeyHeld = true
                self.lastEventTime = now
                print("[Handy] Key \(targetKeyCode) pressed — starting recording")
                self.onRecordingStart?()
                return true
            }
            return false
        }

        let keyUpHandler: (NSEvent) -> Bool = { [weak self] event in
            guard let self else { return false }
            if event.keyCode == targetKeyCode && self.isKeyHeld {
                self.isKeyHeld = false
                self.lastEventTime = ProcessInfo.processInfo.systemUptime
                print("[Handy] Key \(targetKeyCode) released — stopping recording")
                self.onRecordingStop?()
                return true
            }
            return false
        }

        let globalDown = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = keyDownHandler(event)
        }
        let localDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            keyDownHandler(event) ? nil : event
        }
        let globalUp = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { event in
            _ = keyUpHandler(event)
        }
        let localUp = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            keyUpHandler(event) ? nil : event
        }
        if let globalDown { monitors.append(globalDown) }
        if let localDown { monitors.append(localDown) }
        if let globalUp { monitors.append(globalUp) }
        if let localUp { monitors.append(localUp) }
    }

    // MARK: - Toggle Shortcut (Hands-Free)

    private func installToggleMonitor(keyCode targetKeyCode: UInt16, modifierFlags targetModifier: NSEvent.ModifierFlags) {
        let handler: (NSEvent) -> Bool = { [weak self] event in
            guard let self, !self.isPaused else { return false }
            guard !self.isKeyHeld else { return false }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastEventTime > self.debounceInterval else { return false }

            // Check key code matches and required modifiers are held
            let eventMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == targetKeyCode && eventMods.contains(targetModifier) {
                self.lastEventTime = now
                if self.isToggleActive {
                    self.isToggleActive = false
                    print("[Handy] Toggle shortcut pressed — stopping recording")
                    self.onRecordingStop?()
                } else {
                    self.isToggleActive = true
                    print("[Handy] Toggle shortcut pressed — starting recording")
                    self.onRecordingStart?()
                }
                return true
            }
            return false
        }

        let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = handler(event)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event) ? nil : event
        }
        if let global { monitors.append(global) }
        if let local { monitors.append(local) }
    }

    // MARK: - Helpers

    private func startWatchdog(flags: NSEvent.ModifierFlags) {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.isKeyHeld else { return }
            let currentFlags = NSEvent.modifierFlags
            if !currentFlags.contains(flags) {
                self.isKeyHeld = false
                self.onRecordingStop?()
                self.watchdogTimer?.invalidate()
            }
        }
    }

    /// Key codes not allowed as hold keys (A–Z letters and F1–F12).
    static let disallowedHoldKeyCodes: Set<UInt16> = [
        // A–Z letters
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17,
        31, 32, 34, 35, 37, 38, 40, 45, 46,
        // F1–F12
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111
    ]

    // MARK: - Key Display Utilities

    /// Human-readable name for a virtual key code (e.g. 9 → "V", 49 → "Space").
    static func displayName(forKeyCode keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'",
            40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14",
            64: "F17", 79: "F18", 80: "F19", 106: "F16",
            109: "F10", 111: "F12", 113: "F15",
            115: "Home", 116: "⇞", 117: "⌦", 118: "F4",
            119: "End", 120: "F2", 121: "⇟", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }

    /// Symbol string for modifier flags (e.g. option → "⌥", option|shift → "⌥⇧").
    static func displayName(forModifierFlags rawFlags: UInt) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: rawFlags)
        var parts: [String] = []
        if flags.contains(.function) { parts.append("Fn") }
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        if parts.isEmpty { return "None" }
        return parts.joined()
    }

    deinit {
        tearDown()
    }
}
