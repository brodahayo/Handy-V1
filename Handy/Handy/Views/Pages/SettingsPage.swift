import SwiftUI

struct SettingsPage: View {
    @Bindable var appState: AppState

    enum SettingsTab: String, CaseIterable {
        case general, audio, about
    }

    @State private var selectedTab: SettingsTab = .general

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

    @State private var isEditingProfile = false
    @State private var editingName: String = ""
    @State private var editingEmail: String = ""
    @State private var isEditButtonHovered = false
    @State private var showResetConfirmation = false
    @State private var showHoldToggleAlert = false
    @State private var showToggleRecordingAlert = false

    // Key recording state
    enum RecordingTarget { case hold, toggle }
    @State private var recordingTarget: RecordingTarget?
    @State private var recordingMonitors: [Any] = []
    @State private var pendingModifiers: UInt = 0

    var body: some View {
        VStack(spacing: 0) {
            // Capsule tab bar
            CapsuleTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .audio:
                        audioTab
                    case .about:
                        aboutTab
                    }
                }
                .transition(.opacity)
                .id(selectedTab)
            }
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Profile") {
                // Display row — avatar + name + edit button
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Text(profileInitials)
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.userName ?? "No name set")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(appState.userName != nil ? .primary : .secondary)

                        Text(isEditingProfile ? "Editing..." : (appState.userEmail ?? "No email set"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !isEditingProfile {
                        Button("Edit") {
                            editingName = appState.userName ?? ""
                            editingEmail = appState.userEmail ?? ""
                            withAnimation(.spring(duration: 0.25)) {
                                isEditingProfile = true
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .opacity(isEditButtonHovered ? 1.0 : 0.7)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isEditButtonHovered = hovering
                            }
                        }
                    }
                }

                // Expandable edit fields
                if isEditingProfile {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Your name", text: $editingName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Your email", text: $editingEmail)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                        }

                        HStack(spacing: 8) {
                            Spacer()
                            Button("Cancel") {
                                withAnimation(.spring(duration: 0.25)) {
                                    isEditingProfile = false
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            Button("Save") {
                                appState.userName = editingName.isEmpty ? nil : editingName
                                appState.userEmail = editingEmail.isEmpty ? nil : editingEmail
                                withAnimation(.spring(duration: 0.25)) {
                                    isEditingProfile = false
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .padding(.top, 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Section("Hotkeys") {
                HStack(spacing: 10) {
                    // Quick Dictation card — click to record
                    ZStack {
                        VStack(spacing: 0) {
                            Text("HOLD TO DICTATE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.quaternary)
                                .tracking(0.8)
                                .padding(.bottom, 12)

                            if recordingTarget == .hold {
                                Text("Press a key...")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(holdKeyLabel)
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.primary, .primary.opacity(0.35)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }

                            Text("Click to change")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                        }
                        .opacity(appState.settings.holdToDictateEnabled ? 1.0 : 0.3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(recordingTarget == .hold ? Color.accentColor : Color.primary.opacity(0.04), lineWidth: recordingTarget == .hold ? 2 : 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture {
                        guard appState.settings.holdToDictateEnabled else { return }
                        if recordingTarget == .hold {
                            stopKeyRecording()
                        } else {
                            startKeyRecording(for: .hold)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            showHoldToggleAlert = true
                        } label: {
                            Image(systemName: "power")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(appState.settings.holdToDictateEnabled ? .white : Color(white: 0.55))
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .fill(appState.settings.holdToDictateEnabled ? Color.accentColor : Color(white: 0.25))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color(white: 0.12), lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -8)
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
                                Text("The \(holdKeyLabel) key will stop responding until you re-enable it.")
                            } else {
                                Text("The \(holdKeyLabel) key will start responding to key presses again.")
                            }
                        }
                    }

                    // Hands-Free Toggle card — click to record
                    ZStack {
                        VStack(spacing: 0) {
                            Text("TOGGLE RECORDING")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.quaternary)
                                .tracking(0.8)
                                .padding(.bottom, 12)

                            if recordingTarget == .toggle {
                                Text("Press a key...")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(toggleShortcutLabel)
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.primary, .primary.opacity(0.35)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }

                            Text("Click to change")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                        }
                        .opacity(appState.settings.toggleRecordingEnabled ? 1.0 : 0.3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(recordingTarget == .toggle ? Color.accentColor : Color.primary.opacity(0.04), lineWidth: recordingTarget == .toggle ? 2 : 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture {
                        guard appState.settings.toggleRecordingEnabled else { return }
                        if recordingTarget == .toggle {
                            stopKeyRecording()
                        } else {
                            startKeyRecording(for: .toggle)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            showToggleRecordingAlert = true
                        } label: {
                            Image(systemName: "power")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(appState.settings.toggleRecordingEnabled ? .white : Color(white: 0.55))
                                .frame(width: 22, height: 22)
                                .background(
                                    Circle()
                                        .fill(appState.settings.toggleRecordingEnabled ? Color.accentColor : Color(white: 0.25))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color(white: 0.12), lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -8)
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
                }
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

            Section("General") {
                Toggle("Launch at Login", isOn: $appState.settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Audio Tab

    private var audioTab: some View {
        Form {
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
        }
        .formStyle(.grouped)
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        Form {
            Section("About") {
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

    // MARK: - Helpers

    private var holdKeyLabel: String {
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
            // For hold: capture a non-alphabet key OR modifier keys
            let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                if event.keyCode == 53 { // Escape cancels
                    stopKeyRecording()
                    return nil
                }
                // Reject alphabet keys — only allow Space, F-keys, arrows, etc.
                guard !HotkeyManager.disallowedHoldKeyCodes.contains(event.keyCode) else {
                    return nil // ignore, keep listening
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
                    // Released all modifiers — save as modifier-only hold
                    let captured = pendingModifiers
                    stopKeyRecording()
                    appState.settings.holdKeyCode = 65535 // modifier-only
                    appState.settings.holdModifierFlags = captured
                } else if flags != 0 {
                    pendingModifiers = flags
                }
                return nil
            }
            if let keyMonitor { recordingMonitors.append(keyMonitor) }
            if let flagsMonitor { recordingMonitors.append(flagsMonitor) }

        case .toggle:
            // For toggle: capture first keyDown + modifiers
            let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                if event.keyCode == 53 { // Escape
                    stopKeyRecording()
                    return nil
                }
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
                stopKeyRecording()
                appState.settings.toggleKeyCode = event.keyCode
                appState.settings.toggleModifierFlags = mods
                return nil // consume
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

    private var profileInitials: String {
        let name = (appState.userName ?? "").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
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

// MARK: - Capsule Tab Bar

struct CapsuleTabBar: View {
    @Binding var selectedTab: SettingsPage.SettingsTab

    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SettingsPage.SettingsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue.capitalized)
                        .font(.subheadline.weight(selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? .primary : .tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Capsule())
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.03), in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.04), lineWidth: 1))
    }
}
