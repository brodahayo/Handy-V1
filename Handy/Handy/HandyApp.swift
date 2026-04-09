import SwiftUI
import AVFoundation

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
    @State private var meetingRecorder = AudioRecorder()
    @State private var meetingLevelTimer: Timer?
    @State private var accessibilityTimer: Timer?
    @State private var wasAccessibilityTrusted = AXIsProcessTrusted()
    @State private var accessibilityPollCount = 0
    @State private var recordingTargetBundleId: String?

    var body: some Scene {
        WindowGroup {
            if appState.showOnboarding {
                OnboardingView(appState: appState, keychain: keychain) {
                    withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                        appState.showOnboarding = false
                    }
                    // Set up the app after onboarding completes
                    if !didSetup {
                        didSetup = true
                        appState.loadStats()
                        configureHotkeys()
                        soundPlayer.preload(pack: appState.settings.soundPack)
                    }
                }
            } else {
                MainWindowView(appState: appState, onToggle: toggleRecording, onMeetingToggle: toggleMeetingRecording, keychain: keychain)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        guard !didSetup else { return }
                        didSetup = true
                        appState.loadStats()
                        requestPermissions()
                        configureHotkeys()
                        soundPlayer.preload(pack: appState.settings.soundPack)
                    }
                    .onChange(of: appState.settings.holdKeyCode) { configureHotkeys() }
                    .onChange(of: appState.settings.holdModifierFlags) { configureHotkeys() }
                    .onChange(of: appState.settings.toggleKeyCode) { configureHotkeys() }
                    .onChange(of: appState.settings.toggleModifierFlags) { configureHotkeys() }
                    .onChange(of: appState.settings.holdToDictateEnabled) { configureHotkeys() }
                    .onChange(of: appState.settings.toggleRecordingEnabled) { configureHotkeys() }
                    .onChange(of: appState.isRecordingHotkey) { _, recording in
                        hotkeyManager.isPaused = recording
                    }
            }
        }
        .defaultSize(width: 700, height: 500)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView(appState: appState, onToggle: toggleRecording, onQuit: quit)
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
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

        // Ensure mic permission is already granted — don't trigger a system prompt mid-recording
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard authStatus == .authorized else {
            if authStatus == .notDetermined {
                // Request permission first, then retry
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        if granted {
                            self.startRecording()
                        } else {
                            self.appState.errorMessage = "Microphone access is required for recording."
                        }
                    }
                }
            } else {
                appState.errorMessage = "Microphone access denied. Enable it in System Settings → Privacy & Security → Microphone."
            }
            return
        }

        do {
            pasteService.captureTargetApp()
            recordingTargetBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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

        let wavData = audioRecorder.stop()
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let targetBundleId = recordingTargetBundleId
        recordingStartTime = nil
        recordingTargetBundleId = nil
        appState.isRecording = false
        appState.isProcessing = true

        // Switch overlay to processing mode
        if appState.settings.overlayStyle != .none {
            overlay.showProcessing(style: appState.settings.overlayStyle, position: appState.settings.overlayPosition)
        } else {
            overlay.hide()
        }

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await processAudio(wavData: wavData, recordingDuration: duration, targetBundleId: targetBundleId)
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard appState.isProcessing else { return }
                        print("[Handy] Processing timed out after 60 seconds")
                        appState.errorMessage = "Processing timed out. Please try again."
                        appState.isProcessing = false
                        overlay.hide()
                    }
                }
                // When the first task finishes, cancel the other
                await group.next()
                group.cancelAll()
            }
        }
    }

    private func processAudio(wavData: Data?, recordingDuration: TimeInterval = 0, targetBundleId: String? = nil) async {
        guard let wavData else {
            appState.isProcessing = false
            overlay.hide()
            return
        }

        let provider = appState.settings.cloudProvider
        guard let apiKey = try? keychain.retrieve(account: provider.rawValue), !apiKey.isEmpty else {
            appState.errorMessage = "No API key set for \(provider.displayName)"
            appState.isProcessing = false
            overlay.hide()
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
                overlay.hide()
                return
            }

            var finalText = rawText
            if appState.settings.cleanupEnabled {
                let style: CleanupStyle
                if appState.settings.contextAware,
                   let bundleId = targetBundleId,
                   let detected = ContextDetector.cleanupStyle(forBundleId: bundleId) {
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
        overlay.hide()
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
        let holdDisplay = HotkeyManager.displayName(forModifierFlags: appState.settings.holdModifierFlags)
        let toggleDisplay = HotkeyManager.displayName(forModifierFlags: appState.settings.toggleModifierFlags) + HotkeyManager.displayName(forKeyCode: appState.settings.toggleKeyCode)
        print("[Handy] configureHotkeys() called — hold: \(holdDisplay), toggle: \(toggleDisplay)")
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
            holdKeyCode: appState.settings.holdKeyCode,
            holdModifierFlags: appState.settings.holdModifierFlags,
            toggleKeyCode: appState.settings.toggleKeyCode,
            toggleModifierFlags: appState.settings.toggleModifierFlags,
            holdEnabled: appState.settings.holdToDictateEnabled,
            toggleEnabled: appState.settings.toggleRecordingEnabled
        )
        startAccessibilityPolling()
    }

    /// Polls for accessibility permission changes and reconfigures hotkeys
    /// when the permission is newly granted. This is necessary because global
    /// event monitors installed before accessibility is granted don't work —
    /// they must be torn down and reinstalled once the app is trusted.
    private func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        // If already trusted, no need to poll
        if AXIsProcessTrusted() {
            wasAccessibilityTrusted = true
            return
        }
        accessibilityPollCount = 0
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                accessibilityPollCount += 1
                let trusted = AXIsProcessTrusted()
                if trusted && !wasAccessibilityTrusted {
                    print("[Handy] Accessibility permission granted — reconfiguring hotkeys")
                    wasAccessibilityTrusted = true
                    accessibilityTimer?.invalidate()
                    accessibilityTimer = nil
                    hotkeyManager.configure(
                        holdKeyCode: appState.settings.holdKeyCode,
                        holdModifierFlags: appState.settings.holdModifierFlags,
                        toggleKeyCode: appState.settings.toggleKeyCode,
                        toggleModifierFlags: appState.settings.toggleModifierFlags,
                        holdEnabled: appState.settings.holdToDictateEnabled,
                        toggleEnabled: appState.settings.toggleRecordingEnabled
                    )
                } else if accessibilityPollCount >= 300 {
                    // Stop polling after 5 minutes to avoid running forever
                    print("[Handy] Accessibility polling timed out after 5 minutes")
                    accessibilityTimer?.invalidate()
                    accessibilityTimer = nil
                }
            }
        }
    }

    // MARK: - Meeting Notes Recording

    private func toggleMeetingRecording() {
        if appState.isMeetingRecording {
            stopMeetingRecording()
        } else {
            startMeetingRecording()
        }
    }

    private func startMeetingRecording() {
        guard !appState.isMeetingRecording && !appState.isMeetingProcessing else { return }

        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard authStatus == .authorized else {
            if authStatus == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        if granted { startMeetingRecording() }
                        else { appState.errorMessage = "Microphone access is required." }
                    }
                }
            } else {
                appState.errorMessage = "Microphone access denied."
            }
            return
        }

        do {
            soundPlayer.play(pack: appState.settings.soundPack, isStart: true, enabled: appState.settings.soundEnabled)
            try meetingRecorder.start()
            appState.isMeetingRecording = true

            meetingLevelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [self] _ in
                MainActor.assumeIsolated {
                    appState.meetingAudioLevel = meetingRecorder.currentLevel
                }
            }
        } catch {
            appState.errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopMeetingRecording() {
        guard appState.isMeetingRecording else { return }

        soundPlayer.play(pack: appState.settings.soundPack, isStart: false, enabled: appState.settings.soundEnabled)

        meetingLevelTimer?.invalidate()
        meetingLevelTimer = nil

        let wavData = meetingRecorder.stop()
        appState.isMeetingRecording = false
        appState.isMeetingProcessing = true

        Task {
            await processMeetingAudio(wavData: wavData)
        }
    }

    private func processMeetingAudio(wavData: Data?) async {
        guard let wavData else {
            appState.isMeetingProcessing = false
            return
        }

        let provider = appState.settings.cloudProvider
        guard let apiKey = try? keychain.retrieve(account: provider.rawValue), !apiKey.isEmpty else {
            appState.errorMessage = "No API key set for \(provider.displayName)"
            appState.isMeetingProcessing = false
            return
        }

        do {
            let rawText = try await cloudTranscriber.transcribe(
                wavData: wavData,
                provider: provider,
                apiKey: apiKey,
                language: appState.settings.language
            )

            guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                appState.errorMessage = "No speech detected."
                appState.isMeetingProcessing = false
                return
            }

            var finalText = rawText
            if appState.settings.cleanupEnabled {
                finalText = try await textCleanup.cleanup(
                    text: rawText,
                    style: appState.settings.cleanupStyle,
                    provider: provider,
                    apiKey: apiKey
                )
            }

            // Append to meeting notes via notification
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .meetingNoteTranscribed,
                    object: nil,
                    userInfo: ["text": finalText]
                )
            }
        } catch {
            appState.errorMessage = "Transcription failed: \(error.localizedDescription)"
        }

        appState.isMeetingProcessing = false
    }

    private func quit() {
        hotkeyManager.tearDown()
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let meetingNoteTranscribed = Notification.Name("meetingNoteTranscribed")
}
