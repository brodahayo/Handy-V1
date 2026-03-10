import SwiftUI

struct SettingsPage: View {
    @Bindable var appState: AppState

    @State private var updateStatus: UpdateStatus = .idle
    @State private var availableUpdate: AppUpdate?

    private let languages = [
        ("auto", "Auto-detect"), ("en", "English"), ("es", "Spanish"),
        ("fr", "French"), ("de", "German"), ("it", "Italian"),
        ("pt", "Portuguese"), ("nl", "Dutch"), ("ja", "Japanese"),
        ("ko", "Korean"), ("zh", "Chinese"), ("ar", "Arabic"),
        ("hi", "Hindi"), ("ru", "Russian"), ("tr", "Turkish"),
        ("pl", "Polish"), ("sv", "Swedish"), ("da", "Danish"),
        ("no", "Norwegian"), ("fi", "Finnish"),
    ]

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

                Text("Hold the key to record, release to stop and transcribe.")
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

                    Text("+")

                    Picker("Key", selection: $appState.settings.toggleKey) {
                        Text("V").tag("v")
                        Text("D").tag("d")
                        Text("R").tag("r")
                        Text("T").tag("t")
                        Text("Space").tag("space")
                    }
                }

                Text("Press the shortcut to start recording, press again to stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("AI Cleanup") {
                Toggle("Enable AI Cleanup", isOn: $appState.settings.cleanupEnabled)

                if appState.settings.cleanupEnabled {
                    Picker("Style", selection: $appState.settings.cleanupStyle) {
                        ForEach(CleanupStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Toggle("Context-Aware Cleanup", isOn: $appState.settings.contextAware)
                }
            }

            Section("Transcription") {
                Picker("Language", selection: $appState.settings.language) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
            }

            Section("Recording Overlay") {
                HStack(spacing: 16) {
                    OverlayStyleCard(
                        style: .classic,
                        label: "Classic",
                        isSelected: appState.settings.overlayStyle == .classic
                    ) {
                        appState.settings.overlayStyle = .classic
                    }

                    OverlayStyleCard(
                        style: .mini,
                        label: "Mini",
                        isSelected: appState.settings.overlayStyle == .mini
                    ) {
                        appState.settings.overlayStyle = .mini
                    }

                    OverlayStyleCard(
                        style: .none,
                        label: "None",
                        isSelected: appState.settings.overlayStyle == .none
                    ) {
                        appState.settings.overlayStyle = .none
                    }
                }

                if appState.settings.overlayStyle != .none {
                    Picker("Position", selection: $appState.settings.overlayPosition) {
                        Text("Top Center").tag(OverlayPosition.topCenter)
                        Text("Top Left").tag(OverlayPosition.topLeft)
                        Text("Top Right").tag(OverlayPosition.topRight)
                        Text("Bottom Center").tag(OverlayPosition.bottomCenter)
                        Text("Bottom Left").tag(OverlayPosition.bottomLeft)
                        Text("Bottom Right").tag(OverlayPosition.bottomRight)
                    }
                }
            }

            Section("Sound") {
                Toggle("Sound Effects", isOn: $appState.settings.soundEnabled)

                if appState.settings.soundEnabled {
                    Picker("Sound Pack", selection: $appState.settings.soundPack) {
                        ForEach(SoundPack.allCases) { pack in
                            Text(pack.displayName).tag(pack)
                        }
                    }
                }
            }

            Section("General") {
                Picker("Appearance", selection: $appState.settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Toggle("Launch at Login", isOn: $appState.settings.launchAtLogin)
            }

            Section("Debug") {
                Button("Reset Onboarding") {
                    UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                }
                .foregroundStyle(.red)
            }

            Section("About & Updates") {
                HStack {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Handy v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                            .font(.body.weight(.medium))

                        Group {
                            switch updateStatus {
                            case .idle:
                                Text("Click to check for updates")
                                    .foregroundStyle(.secondary)
                            case .checking:
                                Text("Checking for updates...")
                                    .foregroundStyle(.secondary)
                            case .upToDate:
                                Text("You're on the latest version")
                                    .foregroundStyle(.secondary)
                            case .available:
                                if let update = availableUpdate {
                                    Text("Version \(update.version) is available!")
                                        .foregroundStyle(.green)
                                        .fontWeight(.medium)
                                }
                            case .error:
                                Text("Could not check for updates")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.caption)
                    }

                    Spacer()

                    if case .available = updateStatus, let update = availableUpdate, let url = update.downloadURL {
                        Link("Install Update", destination: url)
                            .modifier(GlassProminentButtonModifier())
                            .controlSize(.small)
                    } else {
                        Button {
                            checkForUpdates()
                        } label: {
                            if updateStatus == .checking {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .modifier(GlassButtonModifier())
                        .controlSize(.small)
                        .disabled(updateStatus == .checking)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func checkForUpdates() {
        updateStatus = .checking
        Task {
            do {
                let checker = UpdateChecker()
                if let update = try await checker.checkForUpdates() {
                    availableUpdate = update
                    updateStatus = .available
                } else {
                    updateStatus = .upToDate
                }
            } catch {
                updateStatus = .error
            }
        }
    }
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available
    case error
}
