import SwiftUI

struct HotkeySettingsView: View {
    @Bindable var appState: AppState
    @State private var accessibilityGranted = HotkeyManager.isAccessibilityTrusted
    @State private var showHoldToggleAlert = false
    @State private var showToggleRecordingAlert = false

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
    }

    private var holdKeyDisplayName: String {
        switch appState.settings.holdKey {
        case .fn: return "Fn"
        case .option: return "Option"
        case .optionShift: return "Option+Shift"
        case .command: return "Command"
        case .control: return "Control"
        }
    }
}
