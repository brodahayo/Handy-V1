import SwiftUI

struct HotkeySettingsView: View {
    @Bindable var appState: AppState
    @State private var accessibilityGranted = HotkeyManager.isAccessibilityTrusted

    var body: some View {
        Form {
            Section("Quick Dictation") {
                Picker("Hold Key", selection: $appState.settings.holdKey) {
                    Text("Fn (Globe)").tag(HoldKey.fn)
                    Text("Option (⌥)").tag(HoldKey.option)
                    Text("Option + Shift (⌥⇧)").tag(HoldKey.optionShift)
                    Text("Command (⌘)").tag(HoldKey.command)
                    Text("Control (⌃)").tag(HoldKey.control)
                }

                Text("Hold to record, release to transcribe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hands-Free Shortcut") {
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

                Text("Press to start, press again to stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
}
