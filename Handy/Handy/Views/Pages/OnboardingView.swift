import SwiftUI
import AVFoundation

// MARK: - Design Tokens

private enum OB {
    static let contentWidth: CGFloat = 380
    static let spacing: CGFloat = 24
    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 14
    static let iconFrame: CGFloat = 38
    static let iconRadius: CGFloat = 10

    static let titleFont: Font = .system(size: 26, weight: .bold, design: .rounded)
    static let subtitleFont: Font = .subheadline.weight(.medium)
    static let cardTitle: Font = .system(size: 14, weight: .semibold, design: .rounded)
    static let cardBody: Font = .system(size: 13, weight: .regular, design: .rounded)
    static let buttonFont: Font = .system(size: 15, weight: .semibold, design: .rounded)
    static let labelFont: Font = .caption
    static let hintFont: Font = .system(size: 12, weight: .regular, design: .rounded)

    static let surface = Color.primary.opacity(0.04)
    static let border = Color.primary.opacity(0.04)
    static let buttonWidth: CGFloat = 220
    static let buttonHeight: CGFloat = 44

    static var titleGradient: LinearGradient {
        LinearGradient(
            colors: [.primary, .primary.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @MainActor static let stepTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    static let spring: Animation = .spring(duration: 0.45, bounce: 0.15)
    static let staggerSpring: Animation = .spring(duration: 0.5, bounce: 0.15)
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Bindable var appState: AppState
    let keychain: KeychainService
    let onComplete: () -> Void

    var previewStep: Int = 0
    @State private var currentStep = 0
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var selectedUseCases: Set<String> = []
    @State private var micGranted = false
    @State private var accessibilityGranted = false
    @State private var accessibilityTimer: Timer?
    @State private var selectedProvider: CloudProvider = .groq
    @State private var apiKeyInput = ""
    @State private var apiKeySaved = false

    private let totalSteps = 5

    var body: some View {
        ZStack {
            Color(white: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if currentStep > 0 {
                    OBStepIndicator(currentStep: currentStep, totalSteps: totalSteps)
                        .padding(.top, 28)
                        .transition(.opacity)
                }

                Spacer()

                Group {
                    switch currentStep {
                    case 0: OBWelcomeStep(onGetStarted: nextStep)
                    case 1: OBPersonalizeStep(
                                userName: $userName,
                                userEmail: $userEmail,
                                selectedUseCases: $selectedUseCases,
                                onContinue: nextStep
                            )
                    case 2: OBPrivacyStep(onContinue: nextStep)
                    case 3: OBPermissionsStep(
                                micGranted: $micGranted,
                                accessibilityGranted: $accessibilityGranted,
                                onContinue: nextStep
                            )
                    case 4: OBAISetupStep(
                                selectedProvider: $selectedProvider,
                                apiKeyInput: $apiKeyInput,
                                apiKeySaved: $apiKeySaved,
                                keychain: keychain,
                                onFinish: finishOnboarding,
                                onSkip: finishOnboarding
                            )
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: OB.contentWidth)
                .transition(OB.stepTransition)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if previewStep > 0 { currentStep = previewStep }
            checkMicrophoneStatus()
            startAccessibilityPolling()
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
        }
    }

    private func nextStep() {
        withAnimation(OB.spring) { currentStep += 1 }
    }

    private func finishOnboarding() {
        appState.hasCompletedOnboarding = true
        if !userName.isEmpty { appState.userName = userName }
        if !userEmail.isEmpty { appState.userEmail = userEmail }
        appState.settings.cloudProvider = selectedProvider
        onComplete()
    }

    private func checkMicrophoneStatus() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func startAccessibilityPolling() {
        accessibilityGranted = AXIsProcessTrusted()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                accessibilityGranted = AXIsProcessTrusted()
            }
        }
    }
}

// MARK: - Shared Components

private struct OBTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(OB.titleFont)
                .foregroundStyle(OB.titleGradient)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(OB.subtitleFont)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct OBPrimaryButton: View {
    let label: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(OB.buttonFont)
                .foregroundStyle(.white)
                .frame(width: OB.buttonWidth, height: OB.buttonHeight)
                .background(
                    Capsule()
                        .fill(enabled ? Color.accentColor : Color.primary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct OBTextButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(OB.buttonFont)
                .foregroundStyle(.tertiary)
                .frame(width: OB.buttonWidth, height: 32)
        }
        .buttonStyle(.plain)
    }
}

private struct OBTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 14, design: .rounded))
        .focused($isFocused)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            isFocused ? Color.accentColor.opacity(0.06) : OB.surface,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.4) : OB.border,
                    lineWidth: 1
                )
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

private struct OBCard<Trailing: View>: View {
    let icon: String
    let title: String
    let description: String
    var iconColor: Color = .accentColor
    var trailing: (() -> Trailing)?

    init(
        icon: String,
        title: String,
        description: String,
        iconColor: Color = .accentColor,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.iconColor = iconColor
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: OB.iconFrame, height: OB.iconFrame)
                .background(
                    iconColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: OB.iconRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OB.cardTitle)
                Text(description)
                    .font(OB.cardBody)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if let trailing {
                trailing()
            }
        }
        .padding(OB.cardPadding)
        .background(OB.surface, in: RoundedRectangle(cornerRadius: OB.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OB.cardRadius, style: .continuous)
                .stroke(OB.border, lineWidth: 1)
        )
    }
}

extension OBCard where Trailing == EmptyView {
    init(icon: String, title: String, description: String, iconColor: Color = .accentColor) {
        self.icon = icon
        self.title = title
        self.description = description
        self.iconColor = iconColor
        self.trailing = nil
    }
}

private struct OBStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.accentColor : Color.primary.opacity(0.1))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(duration: 0.35, bounce: 0.2), value: currentStep)
            }
        }
    }
}

/// Stagger-fade modifier to reduce boilerplate in each step.
private struct StaggerAppear: ViewModifier {
    let appeared: Bool
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
    }
}

private extension View {
    func stagger(_ appeared: Bool) -> some View {
        modifier(StaggerAppear(appeared: appeared))
    }
}

// MARK: - Step 1: Welcome

private struct OBWelcomeStep: View {
    let onGetStarted: () -> Void

    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: OB.spacing) {
            appLogo
            titleGroup
            OBPrimaryButton(label: "Get Started", action: onGetStarted)
                .scaleEffect(showButton ? 1 : 0.9)
                .opacity(showButton ? 1 : 0)
        }
        .onAppear { animateEntrance() }
    }

    private var appLogo: some View {
        Image("AppLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .accentColor.opacity(0.25), radius: 24, y: 4)
            .scaleEffect(showLogo ? 1 : 0.6)
            .opacity(showLogo ? 1 : 0)
    }

    private var titleGroup: some View {
        VStack(spacing: 6) {
            Text("Handy")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(OB.titleGradient)
            Text("Voice to Text")
                .font(OB.subtitleFont)
                .foregroundStyle(.tertiary)
        }
        .scaleEffect(showTitle ? 1 : 0.9)
        .opacity(showTitle ? 1 : 0)
    }

    private func animateEntrance() {
        withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.1)) { showLogo = true }
        withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.3)) { showTitle = true }
        withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.5)) { showButton = true }
    }
}

// MARK: - Step 2: Personalize

private struct OBPersonalizeStep: View {
    @Binding var userName: String
    @Binding var userEmail: String
    @Binding var selectedUseCases: Set<String>
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var showEmailError = false

    private let useCases = [
        "Writing", "Email", "Notes", "Code",
        "Social Media", "Journaling", "School", "Accessibility"
    ]

    private var isValidEmail: Bool {
        let trimmed = userEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private var canContinue: Bool {
        !userName.trimmingCharacters(in: .whitespaces).isEmpty && isValidEmail
    }

    var body: some View {
        VStack(spacing: OB.spacing) {
            OBTitle(title: "Personalize Your Experience", subtitle: "Tell us a bit about yourself")
                .stagger(appeared)

            inputFields
                .stagger(appeared)

            useCaseSection
                .stagger(appeared)

            continueSection
                .stagger(appeared)
        }
        .onAppear {
            withAnimation(OB.staggerSpring) { appeared = true }
        }
    }

    private var inputFields: some View {
        VStack(spacing: 14) {
            OBTextField(placeholder: "Your name", text: $userName)

            VStack(alignment: .leading, spacing: 4) {
                OBTextField(placeholder: "Email address", text: $userEmail)
                    .onChange(of: userEmail) { _, _ in
                        if showEmailError { showEmailError = false }
                    }

                if showEmailError {
                    Text("Please enter a valid email address")
                        .font(OB.hintFont)
                        .foregroundStyle(.red)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var useCaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What will you use Handy for?")
                .font(OB.labelFont)
                .foregroundStyle(.tertiary)

            FlowLayout(spacing: 8) {
                ForEach(useCases, id: \.self) { useCase in
                    OBChip(
                        label: useCase,
                        isSelected: selectedUseCases.contains(useCase)
                    ) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            if selectedUseCases.contains(useCase) {
                                selectedUseCases.remove(useCase)
                            } else {
                                selectedUseCases.insert(useCase)
                            }
                        }
                    }
                }
            }
        }
    }

    private var continueSection: some View {
        VStack(spacing: 6) {
            OBPrimaryButton(label: "Continue", enabled: canContinue) {
                if !isValidEmail {
                    withAnimation(.spring(duration: 0.3)) { showEmailError = true }
                    return
                }
                onContinue()
            }

            if !canContinue {
                Text("Name and email are required")
                    .font(OB.hintFont)
                    .foregroundStyle(.quaternary)
            }
        }
    }
}

// MARK: - Step 3: Privacy

private struct OBPrivacyStep: View {
    let onContinue: () -> Void

    @State private var showItems: [Bool] = [false, false, false]
    @State private var showButton = false

    private let features: [(icon: String, title: String, description: String)] = [
        ("desktopcomputer", "Local Processing", "Your transcriptions stay on your device. Audio is processed locally whenever possible."),
        ("icloud.slash", "No Cloud Storage", "Nothing is uploaded without your explicit permission. Your data is yours."),
        ("lock.shield", "Encrypted Settings", "API keys and sensitive settings are stored securely on your machine.")
    ]

    var body: some View {
        VStack(spacing: OB.spacing) {
            OBTitle(title: "Your Privacy Matters", subtitle: "Handy is designed with privacy first")

            VStack(spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    OBCard(icon: feature.icon, title: feature.title, description: feature.description)
                        .opacity(showItems[index] ? 1 : 0)
                        .offset(y: showItems[index] ? 0 : 12)
                }
            }

            OBPrimaryButton(label: "Continue", action: onContinue)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 10)
        }
        .onAppear {
            for i in 0..<features.count {
                withAnimation(OB.staggerSpring.delay(Double(i) * 0.15)) {
                    showItems[i] = true
                }
            }
            withAnimation(OB.staggerSpring.delay(0.5)) { showButton = true }
        }
    }
}

// MARK: - Step 4: Permissions

private struct OBPermissionsStep: View {
    @Binding var micGranted: Bool
    @Binding var accessibilityGranted: Bool
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var accessibilityOpened = false

    var body: some View {
        VStack(spacing: OB.spacing) {
            OBTitle(title: "Grant Permissions", subtitle: "Handy needs these to work properly")
                .stagger(appeared)

            VStack(spacing: 10) {
                micCard
                accessibilityCard

                if accessibilityOpened && !accessibilityGranted {
                    Text("After enabling Accessibility in System Settings, you may need to restart Handy for it to take effect.")
                        .font(OB.hintFont)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .stagger(appeared)

            VStack(spacing: 6) {
                OBPrimaryButton(label: "Continue", enabled: micGranted, action: onContinue)

                hintText
            }
            .stagger(appeared)
        }
        .onAppear {
            withAnimation(OB.staggerSpring) { appeared = true }
        }
    }

    private var micCard: some View {
        OBCard(
            icon: "mic.fill",
            title: "Microphone",
            description: "Required for voice recording",
            iconColor: micGranted ? .green : .accentColor
        ) {
            permissionBadge(granted: micGranted) {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async { micGranted = granted }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: micGranted)
    }

    private var accessibilityCard: some View {
        OBCard(
            icon: "accessibility",
            title: "Accessibility",
            description: "For global shortcut and auto-paste",
            iconColor: accessibilityGranted ? .green : .accentColor
        ) {
            permissionBadge(granted: accessibilityGranted) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                accessibilityOpened = true
            }
        }
        .animation(.spring(duration: 0.3), value: accessibilityGranted)
    }

    @ViewBuilder
    private func permissionBadge(granted: Bool, action: @escaping () -> Void) -> some View {
        if granted {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        } else {
            Button("Grant", action: action)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.accentColor, in: Capsule())
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var hintText: some View {
        if !micGranted {
            Text("Microphone permission is required")
                .font(OB.hintFont)
                .foregroundStyle(.quaternary)
        } else if !accessibilityGranted {
            Text("You can grant Accessibility later in Settings")
                .font(OB.hintFont)
                .foregroundStyle(.quaternary)
        }
    }
}

// MARK: - Step 5: AI Setup

private struct OBAISetupStep: View {
    @Binding var selectedProvider: CloudProvider
    @Binding var apiKeyInput: String
    @Binding var apiKeySaved: Bool
    let keychain: KeychainService
    let onFinish: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: OB.spacing) {
            OBTitle(title: "Set Up Your AI", subtitle: "Choose a cloud provider for transcription")
                .stagger(appeared)

            VStack(spacing: 16) {
                providerPicker
                apiKeySection
            }
            .stagger(appeared)

            VStack(spacing: 6) {
                OBPrimaryButton(label: "Finish Setup", action: onFinish)
                OBTextButton(label: "Skip for Now", action: onSkip)
            }
            .stagger(appeared)
        }
        .onAppear {
            withAnimation(OB.staggerSpring) { appeared = true }
        }
        .onChange(of: selectedProvider) {
            apiKeyInput = (try? keychain.retrieve(account: selectedProvider.rawValue)) ?? ""
            apiKeySaved = false
        }
    }

    private var providerPicker: some View {
        HStack(spacing: 8) {
            ForEach(CloudProvider.allCases) { provider in
                Button {
                    withAnimation(.spring(duration: 0.3)) { selectedProvider = provider }
                } label: {
                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedProvider == provider ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedProvider == provider
                                ? AnyShapeStyle(Color.accentColor)
                                : AnyShapeStyle(OB.surface),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(
                                selectedProvider == provider ? Color.clear : OB.border,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(selectedProvider.displayName) API Key")
                .font(OB.labelFont)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                OBTextField(placeholder: "Paste your API key", text: $apiKeyInput, isSecure: true)

                Button {
                    try? keychain.save(account: selectedProvider.rawValue, value: apiKeyInput)
                    withAnimation(.spring(duration: 0.3)) { apiKeySaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { apiKeySaved = false }
                    }
                } label: {
                    Text(apiKeySaved ? "Saved" : "Save")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 38)
                        .background(
                            apiKeyInput.isEmpty
                                ? Color.primary.opacity(0.12)
                                : (apiKeySaved ? Color.green : Color.accentColor),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .contentTransition(.numericText())
                }
                .buttonStyle(.plain)
                .disabled(apiKeyInput.isEmpty)
            }

            Link("Get \(selectedProvider.displayName) API Key \u{2192}", destination: selectedProvider.apiKeyURL)
                .font(OB.hintFont)
                .foregroundStyle(Color.accentColor.opacity(0.8))
        }
    }
}

// MARK: - Chip

private struct OBChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(OB.surface),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.clear : OB.border,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, in: proposal.width ?? 0)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(subviews: Subviews, in width: CGFloat) -> (positions: [CGPoint], height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, y + rowHeight)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(
        appState: AppState(),
        keychain: KeychainService(),
        onComplete: {}
    )
    .frame(width: 700, height: 500)
}
