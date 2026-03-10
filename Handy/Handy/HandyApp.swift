import SwiftUI

@main
struct HandyApp: App {
    @State private var appState = AppState()
    @State private var hotkeyManager = HotkeyManager()
    @State private var audioRecorder = AudioRecorder()
    @State private var soundPlayer = SoundPlayer()
    @State private var cloudTranscriber = CloudTranscriber()
    @State private var textCleanup = TextCleanup()
    @State private var pasteService = PasteService()
    @State private var keychain = KeychainService()
    @State private var settingsPersistence = SettingsPersistence()
    @State private var overlay = RecordingOverlay()
    @State private var levelTimer: Timer?
    @State private var recordingStartTime: Date?
    @State private var didSetup = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView(appState: appState, keychain: keychain) {
                    withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                        showOnboarding = false
                    }
                    // Set up the app after onboarding completes
                    if !didSetup {
                        didSetup = true
                        appState.loadStats()
                        configureHotkeys()
                    }
                }
            } else {
                MainWindowView(appState: appState, onToggle: toggleRecording, keychain: keychain)
                    .preferredColorScheme(appState.settings.appearanceMode.colorScheme)
                    .onAppear {
                        guard !didSetup else { return }
                        didSetup = true
                        appState.loadStats()
                        requestPermissions()
                        configureHotkeys()
                    }
                    .onChange(of: appState.settings.holdKey) { configureHotkeys() }
                    .onChange(of: appState.settings.toggleModifier) { configureHotkeys() }
                    .onChange(of: appState.settings.toggleKey) { configureHotkeys() }
            }
        }
        .defaultSize(width: 700, height: 500)

        MenuBarExtra {
            MenuBarView(appState: appState, onToggle: toggleRecording, onQuit: quit)
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
        }

        Settings {
            SettingsView(appState: appState, keychain: keychain)
        }
    }

    private func toggleRecording() {
        if appState.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard !appState.isRecording && !appState.isProcessing else { return }
        do {
            pasteService.captureTargetApp()
            soundPlayer.play(pack: appState.settings.soundPack, isStart: true, enabled: appState.settings.soundEnabled)
            try audioRecorder.start()
            appState.isRecording = true
            recordingStartTime = Date()

            // Show overlay
            if appState.settings.overlayStyle != .none {
                overlay.show(style: appState.settings.overlayStyle, position: appState.settings.overlayPosition, level: 0)
                levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [self] _ in
                    MainActor.assumeIsolated {
                        let level = audioRecorder.currentLevel
                        appState.audioLevel = level
                        overlay.updateLevel(level, style: appState.settings.overlayStyle)
                    }
                }
            }
        } catch {
            appState.errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        guard appState.isRecording else { return }

        soundPlayer.play(pack: appState.settings.soundPack, isStart: false, enabled: appState.settings.soundEnabled)

        levelTimer?.invalidate()
        levelTimer = nil
        overlay.hide()

        let wavData = audioRecorder.stop()
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartTime = nil
        appState.isRecording = false
        appState.isProcessing = true

        Task {
            await processAudio(wavData: wavData, recordingDuration: duration)
        }
    }

    private func processAudio(wavData: Data?, recordingDuration: TimeInterval = 0) async {
        guard let wavData else {
            appState.isProcessing = false
            return
        }

        let provider = appState.settings.cloudProvider
        guard let apiKey = try? keychain.retrieve(account: provider.rawValue), !apiKey.isEmpty else {
            appState.errorMessage = "No API key set for \(provider.displayName)"
            appState.isProcessing = false
            return
        }

        do {
            let rawText = try await cloudTranscriber.transcribe(
                wavData: wavData,
                provider: provider,
                apiKey: apiKey,
                language: appState.settings.language
            )
            appState.lastRawText = rawText

            // Skip cleanup and paste if transcription is empty (no speech detected)
            guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("[Handy] Empty transcription — no speech detected, skipping paste")
                appState.errorMessage = "No speech detected. Try speaking louder or recording longer."
                appState.isProcessing = false
                return
            }

            var finalText = rawText
            if appState.settings.cleanupEnabled {
                let style: CleanupStyle
                if appState.settings.contextAware, let detected = ContextDetector.detectCleanupStyle() {
                    style = detected
                } else {
                    style = appState.settings.cleanupStyle
                }
                finalText = try await textCleanup.cleanup(text: rawText, style: style, provider: provider, apiKey: apiKey)
            }

            appState.lastTranscription = finalText
            appState.recordTranscription(text: finalText, recordingDuration: recordingDuration)
            pasteService.paste(finalText)
        } catch {
            appState.errorMessage = "Transcription failed: \(error.localizedDescription)"
        }

        appState.isProcessing = false
    }

    private func requestPermissions() {
        // Prompt for Accessibility — needed for auto-paste (Cmd+V simulation)
        HotkeyManager.requestAccessibilityPermissions()

        if !AXIsProcessTrusted() {
            // Give the system a moment to show its own prompt, then check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if !AXIsProcessTrusted() {
                    let alert = NSAlert()
                    alert.messageText = "Accessibility Access Required"
                    alert.informativeText = "Handy needs Accessibility access to paste transcriptions into your apps.\n\nGo to System Settings → Privacy & Security → Accessibility and enable Handy."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Open System Settings")
                    alert.addButton(withTitle: "Later")

                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
        }
    }

    private func configureHotkeys() {
        print("[Handy] configureHotkeys() called — holdKey: \(appState.settings.holdKey), toggle: \(appState.settings.toggleModifier)+\(appState.settings.toggleKey)")
        hotkeyManager.onRecordingStart = { [self] in
            MainActor.assumeIsolated {
                print("[Handy] onRecordingStart callback fired")
                if !appState.isRecording {
                    startRecording()
                }
            }
        }
        hotkeyManager.onRecordingStop = { [self] in
            MainActor.assumeIsolated {
                print("[Handy] onRecordingStop callback fired")
                if appState.isRecording {
                    stopRecording()
                }
            }
        }
        hotkeyManager.configure(
            holdKey: appState.settings.holdKey,
            toggleModifier: appState.settings.toggleModifier,
            toggleKey: appState.settings.toggleKey
        )
    }

    private func quit() {
        hotkeyManager.tearDown()
        NSApplication.shared.terminate(nil)
    }
}
