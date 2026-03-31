import Cocoa

final class HotkeyManager: @unchecked Sendable {
    var onRecordingStart: (@Sendable () -> Void)?
    var onRecordingStop: (@Sendable () -> Void)?

    private var monitors: [Any] = []
    private var isKeyHeld = false
    private var isToggleActive = false
    private var watchdogTimer: Timer?
    private var lastEventTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.15

    var isConfigured: Bool { !monitors.isEmpty }

    /// Configure both Quick Dictation (hold) and Hands-Free (toggle) simultaneously.
    /// Both modes are always active — hold key for quick dictation, toggle shortcut for hands-free.
    func configure(holdKey: HoldKey, toggleModifier: String, toggleKey: String) {
        tearDown()

        print("[Handy] Configuring hotkeys — holdKey: \(holdKey), toggle: \(toggleModifier)+\(toggleKey)")

        // Always install the hold-key monitor
        if holdKey == .fn {
            installFnHoldMonitor()
        } else {
            installModifierHoldMonitor(holdKey: holdKey)
        }

        // Always install the toggle monitor alongside
        installToggleMonitor(modifier: toggleModifier, key: toggleKey)

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

    // MARK: - Fn Key (Hold Globe/Fn)

    private func installFnHoldMonitor() {
        let handler: (NSEvent) -> Bool = { [weak self] event in
            guard let self, !self.isToggleActive else { return false }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastEventTime > self.debounceInterval else { return false }

            let fnDown = event.modifierFlags.contains(.function)

            if fnDown && !self.isKeyHeld {
                self.isKeyHeld = true
                self.lastEventTime = now
                print("[Handy] Fn key pressed — starting recording")
                self.onRecordingStart?()
                self.startWatchdog(flags: .function)
                return true
            } else if !fnDown && self.isKeyHeld {
                self.isKeyHeld = false
                self.lastEventTime = now
                print("[Handy] Fn key released — stopping recording")
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
            // Return nil to consume the event and prevent the macOS system beep
            handler(event) ? nil : event
        }
        if let global { monitors.append(global) }
        if let local { monitors.append(local) }
    }

    // MARK: - Hold Modifier Key

    private func installModifierHoldMonitor(holdKey: HoldKey) {
        let targetFlags = modifierFlags(for: holdKey)

        let handler: (NSEvent) -> Bool = { [weak self] event in
            guard let self, !self.isToggleActive else { return false }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastEventTime > self.debounceInterval else { return false }

            let pressed = event.modifierFlags.contains(targetFlags)

            if pressed && !self.isKeyHeld {
                self.isKeyHeld = true
                self.lastEventTime = now
                print("[Handy] Modifier key pressed — starting recording")
                self.onRecordingStart?()
                self.startWatchdog(flags: targetFlags)
                return true
            } else if !pressed && self.isKeyHeld {
                self.isKeyHeld = false
                self.lastEventTime = now
                print("[Handy] Modifier key released — stopping recording")
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

    // MARK: - Toggle Shortcut (Hands-Free)

    private func installToggleMonitor(modifier: String, key: String) {
        let targetModifier = modifierFlags(forName: modifier)
        let targetKeyCode = keyCode(forName: key)

        /// Returns true if the event matched the toggle shortcut and was handled.
        let handler: (NSEvent) -> Bool = { [weak self] event in
            guard let self else { return false }
            // Don't toggle while hold-key is active
            guard !self.isKeyHeld else { return false }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastEventTime > self.debounceInterval else { return false }

            if event.keyCode == targetKeyCode && event.modifierFlags.contains(targetModifier) {
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
            // Return nil to consume the event and prevent the macOS system beep
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

    private func modifierFlags(for holdKey: HoldKey) -> NSEvent.ModifierFlags {
        switch holdKey {
        case .fn: return .function
        case .option: return .option
        case .optionShift: return [.option, .shift]
        case .command: return .command
        case .control: return .control
        }
    }

    private func modifierFlags(forName name: String) -> NSEvent.ModifierFlags {
        switch name.lowercased() {
        case "option", "alt": return .option
        case "command", "cmd": return .command
        case "control", "ctrl": return .control
        case "shift": return .shift
        default: return .option
        }
    }

    private func keyCode(forName name: String) -> UInt16 {
        switch name.lowercased() {
        case "v": return 9
        case "d": return 2
        case "r": return 15
        case "t": return 17
        case "space": return 49
        default: return 9
        }
    }

    deinit {
        tearDown()
    }
}
