import SwiftUI

struct HotkeySettingsView: View {
    @Bindable var appState: AppState
    @State private var accessibilityGranted = HotkeyManager.isAccessibilityTrusted
    @State private var showHoldToggleAlert = false
    @State private var showToggleRecordingAlert = false

    // Key recording state
    enum RecordingTarget { case hold, toggle }
    @State private var recordingTarget: RecordingTarget?
    @State private var recordingMonitors: [Any] = []
    @State private var pendingModifiers: UInt = 0

    var body: some View {
        Form {
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
                            Text("The \(holdKeyDisplayName) key will stop responding until you re-enable it.")
                        } else {
                            Text("The \(holdKeyDisplayName) key will start responding to key presses again.")
                        }
                    }
                }

                // Click-to-record hold key
                Button {
                    guard appState.settings.holdToDictateEnabled else { return }
                    if recordingTarget == .hold {
                        stopKeyRecording()
                    } else {
                        startKeyRecording(for: .hold)
                    }
                } label: {
                    HStack {
                        Text("Hold Key")
                        Spacer()
                        Text(recordingTarget == .hold ? "Press a key..." : holdKeyDisplayName)
                            .foregroundStyle(recordingTarget == .hold ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(recordingTarget == .hold ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(!appState.settings.holdToDictateEnabled)
                .opacity(appState.settings.holdToDictateEnabled ? 1.0 : 0.35)
            }

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
                            Text("The \(toggleShortcutLabel) shortcut will stop responding until you re-enable it.")
                        } else {
                            Text("The \(toggleShortcutLabel) shortcut will start responding to key presses again.")
                        }
                    }
                }

                // Click-to-record toggle shortcut
                Button {
                    guard appState.settings.toggleRecordingEnabled else { return }
                    if recordingTarget == .toggle {
                        stopKeyRecording()
                    } else {
                        startKeyRecording(for: .toggle)
                    }
                } label: {
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        Text(recordingTarget == .toggle ? "Press a key..." : toggleShortcutLabel)
                            .foregroundStyle(recordingTarget == .toggle ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(recordingTarget == .toggle ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(!appState.settings.toggleRecordingEnabled)
                .opacity(appState.settings.toggleRecordingEnabled ? 1.0 : 0.35)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityGranted ? .green : .orange)
                    Text(accessibilityGranted ? "Accessibility access granted" : "Accessibility access required for hotkeys")
                        .foregroundStyle(accessibilityGranted ? .secondary : .primary)
                    Spacer()
                    if !accessibilityGranted {
                        Button("Grant Access") {
                            HotkeyManager.requestAccessibilityPermissions()
                        }
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $appState.settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            accessibilityGranted = HotkeyManager.isAccessibilityTrusted
        }
        .onDisappear {
            stopKeyRecording()
        }
    }

    private var holdKeyDisplayName: String {
        let s = appState.settings
        if s.holdKeyCode == 65535 {
            return HotkeyManager.displayName(forModifierFlags: s.holdModifierFlags)
        }
        let mods = HotkeyManager.displayName(forModifierFlags: s.holdModifierFlags)
        let key = HotkeyManager.displayName(forKeyCode: s.holdKeyCode)
        return mods == "None" ? key : "\(mods)\(key)"
    }

    private var toggleShortcutLabel: String {
        let mods = HotkeyManager.displayName(forModifierFlags: appState.settings.toggleModifierFlags)
        let key = HotkeyManager.displayName(forKeyCode: appState.settings.toggleKeyCode)
        return mods.isEmpty || mods == "None" ? key : "\(mods)\(key)"
    }

    // MARK: - Key Recording

    private func startKeyRecording(for target: RecordingTarget) {
        stopKeyRecording()
        recordingTarget = target
        pendingModifiers = 0
        appState.isRecordingHotkey = true

        switch target {
        case .hold:
            let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                if event.keyCode == 53 {
                    stopKeyRecording()
                    return nil
                }
                guard !HotkeyManager.disallowedHoldKeyCodes.contains(event.keyCode) else {
                    return nil // ignore alphabet keys
                }
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
                stopKeyRecording()
                appState.settings.holdKeyCode = event.keyCode
                appState.settings.holdModifierFlags = mods
                return nil
            }
            let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [self] event in
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
                if flags == 0 && pendingModifiers != 0 {
                    let captured = pendingModifiers
                    stopKeyRecording()
                    appState.settings.holdKeyCode = 65535
                    appState.settings.holdModifierFlags = captured
                } else if flags != 0 {
                    pendingModifiers = flags
                }
                return nil
            }
            if let keyMonitor { recordingMonitors.append(keyMonitor) }
            if let flagsMonitor { recordingMonitors.append(flagsMonitor) }

        case .toggle:
            let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                if event.keyCode == 53 {
                    stopKeyRecording()
                    return nil
                }
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
                stopKeyRecording()
                appState.settings.toggleKeyCode = event.keyCode
                appState.settings.toggleModifierFlags = mods
                return nil
            }
            if let keyMonitor { recordingMonitors.append(keyMonitor) }
        }
    }

    private func stopKeyRecording() {
        for monitor in recordingMonitors {
            NSEvent.removeMonitor(monitor)
        }
        recordingMonitors.removeAll()
        recordingTarget = nil
        pendingModifiers = 0
        appState.isRecordingHotkey = false
    }
}
