import SwiftUI
import AVFoundation

// MARK: - Constants

private enum OnboardingStyle {
    static let contentWidth: CGFloat = 380
    static let sectionSpacing: CGFloat = 28
    static let titleSize: CGFloat = 24
    static let subtitleFont: Font = .system(size: 15, weight: .medium, design: .rounded)
    static let buttonWidth: CGFloat = 220
    static let buttonHeight: CGFloat = 46
    static let buttonFont: Font = .system(size: 16, weight: .semibold, design: .rounded)
    static let cardCornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 14
    static let cardIconSize: CGFloat = 40
    static let cardIconCornerRadius: CGFloat = 10
    static let cardTitleFont: Font = .system(size: 15, weight: .semibold, design: .rounded)
    static let cardDescriptionFont: Font = .system(size: 13, weight: .regular, design: .rounded)
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
            AnimatedGradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step indicator (visible on steps 1-4, hidden on welcome)
                if currentStep > 0 {
                    StepIndicator(currentStep: currentStep, totalSteps: totalSteps)
                        .padding(.top, 28)
                        .transition(.opacity)
                }

                Spacer()

                Group {
                    switch currentStep {
                    case 0:
                        WelcomeStep(onGetStarted: nextStep)
                    case 1:
                        PersonalizeStep(
                            userName: $userName,
                            userEmail: $userEmail,
                            selectedUseCases: $selectedUseCases,
                            onContinue: nextStep
                        )
                    case 2:
                        PrivacyStep(onContinue: nextStep)
                    case 3:
                        PermissionsStep(
                            micGranted: $micGranted,
                            accessibilityGranted: $accessibilityGranted,
                            onContinue: nextStep
                        )
                    case 4:
                        AISetupStep(
                            selectedProvider: $selectedProvider,
                            apiKeyInput: $apiKeyInput,
                            apiKeySaved: $apiKeySaved,
                            keychain: keychain,
                            onFinish: finishOnboarding,
                            onSkip: finishOnboarding
                        )
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: OnboardingStyle.contentWidth)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()
            }
        }
        .preferredColorScheme(.light)
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
        withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
            currentStep += 1
        }
    }

    private func finishOnboarding() {
        appState.hasCompletedOnboarding = true
        if !userName.isEmpty {
            appState.userName = userName
        }
        appState.settings.cloudProvider = selectedProvider
        onComplete()
    }

    private func checkMicrophoneStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micGranted = true
        default:
            micGranted = false
        }
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

private struct OnboardingTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: OnboardingStyle.titleSize, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(OnboardingStyle.subtitleFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct OnboardingButton: View {
    let label: String
    var style: ButtonVariant = .primary
    let action: () -> Void

    enum ButtonVariant {
        case primary
        case gradient
        case disabled
        case text
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(OnboardingStyle.buttonFont)
                .foregroundStyle(style == .text ? Color.secondary : Color.white)
                .frame(width: OnboardingStyle.buttonWidth, height: style == .text ? 32 : OnboardingStyle.buttonHeight)
                .background { backgroundView }
        }
        .buttonStyle(.plain)
        .disabled(style == .disabled)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Capsule().fill(Color.blue)
        case .gradient:
            Capsule().fill(LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            ))
        case .disabled:
            Capsule().fill(Color.gray)
        case .text:
            EmptyView()
        }
    }
}

private struct OnboardingTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14, design: .rounded))
            .focused($isFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isFocused ? Color.blue.opacity(0.04) : Color.black.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? Color.blue.opacity(0.5) : Color.black.opacity(0.08), lineWidth: isFocused ? 1.5 : 1)
            )
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

private struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    var iconColor: Color = .blue
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: OnboardingStyle.cardIconSize, height: OnboardingStyle.cardIconSize)
                .background(
                    iconColor.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: OnboardingStyle.cardIconCornerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OnboardingStyle.cardTitleFont)
                Text(description)
                    .font(OnboardingStyle.cardDescriptionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if let trailing {
                trailing
            }
        }
        .padding(OnboardingStyle.cardPadding)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: OnboardingStyle.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.blue : Color.black.opacity(0.1))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(duration: 0.35, bounce: 0.2), value: currentStep)
            }
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onGetStarted: () -> Void

    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 28) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .blue.opacity(0.35), radius: 24, y: 4)
                .shadow(color: .purple.opacity(0.15), radius: 40, y: 8)
                .scaleEffect(showLogo ? 1 : 0.6)
                .opacity(showLogo ? 1 : 0)

            VStack(spacing: 8) {
                Text("Handy")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Voice to Text")
                    .font(OnboardingStyle.subtitleFont)
                    .foregroundStyle(.secondary)
            }
            .scaleEffect(showTitle ? 1 : 0.9)
            .opacity(showTitle ? 1 : 0)

            OnboardingButton(label: "Get Started", action: onGetStarted)
                .scaleEffect(showButton ? 1 : 0.9)
                .opacity(showButton ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.1)) {
                showLogo = true
            }
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.3)) {
                showTitle = true
            }
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.5)) {
                showButton = true
            }
        }
    }
}

// MARK: - Step 2: Personalize

private struct PersonalizeStep: View {
    @Binding var userName: String
    @Binding var userEmail: String
    @Binding var selectedUseCases: Set<String>
    let onContinue: () -> Void

    @State private var appeared = false

    private let useCases = [
        "Writing", "Email", "Notes", "Code",
        "Social Media", "Journaling", "School", "Accessibility"
    ]

    var body: some View {
        VStack(spacing: OnboardingStyle.sectionSpacing) {
            OnboardingTitle(
                title: "Personalize Your Experience",
                subtitle: "Tell us a bit about yourself"
            )
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            VStack(spacing: 14) {
                OnboardingTextField(placeholder: "Your name", text: $userName)
                OnboardingTextField(placeholder: "Email address", text: $userEmail)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            VStack(alignment: .leading, spacing: 12) {
                Text("What will you use Handy for?")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(useCases, id: \.self) { useCase in
                        UseCaseChip(
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
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            OnboardingButton(label: "Continue", action: onContinue)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                appeared = true
            }
        }
    }
}

// MARK: - Step 3: Privacy

private struct PrivacyStep: View {
    let onContinue: () -> Void

    @State private var showItems: [Bool] = [false, false, false]
    @State private var showButton = false

    private let features: [(icon: String, title: String, description: String)] = [
        ("desktopcomputer", "Local Processing", "Your transcriptions stay on your device. Audio is processed locally whenever possible."),
        ("icloud.slash", "No Cloud Storage", "Nothing is uploaded without your explicit permission. Your data is yours."),
        ("lock.shield", "Encrypted Settings", "API keys and sensitive settings are stored securely on your machine.")
    ]

    var body: some View {
        VStack(spacing: OnboardingStyle.sectionSpacing) {
            OnboardingTitle(
                title: "Your Privacy Matters",
                subtitle: "Handy is designed with privacy first"
            )

            VStack(spacing: 12) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    InfoCard(icon: feature.icon, title: feature.title, description: feature.description)
                        .opacity(showItems[index] ? 1 : 0)
                        .offset(y: showItems[index] ? 0 : 12)
                }
            }

            OnboardingButton(label: "Continue", action: onContinue)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 10)
        }
        .onAppear {
            for i in 0..<features.count {
                withAnimation(.spring(duration: 0.5, bounce: 0.15).delay(Double(i) * 0.15)) {
                    showItems[i] = true
                }
            }
            withAnimation(.spring(duration: 0.5, bounce: 0.15).delay(0.5)) {
                showButton = true
            }
        }
    }
}

// MARK: - Step 4: Permissions

private struct PermissionsStep: View {
    @Binding var micGranted: Bool
    @Binding var accessibilityGranted: Bool
    let onContinue: () -> Void

    @State private var appeared = false

    private var bothGranted: Bool {
        micGranted && accessibilityGranted
    }

    var body: some View {
        VStack(spacing: OnboardingStyle.sectionSpacing) {
            OnboardingTitle(
                title: "Grant Permissions",
                subtitle: "Handy needs these to work properly"
            )
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            VStack(spacing: 12) {
                InfoCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required for voice recording",
                    iconColor: micGranted ? .green : .blue,
                    trailing: AnyView(
                        permissionTrailing(isGranted: micGranted) {
                            AVCaptureDevice.requestAccess(for: .audio) { granted in
                                DispatchQueue.main.async { micGranted = granted }
                            }
                        }
                    )
                )
                .animation(.spring(duration: 0.3), value: micGranted)

                InfoCard(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "For global shortcut and auto-paste",
                    iconColor: accessibilityGranted ? .green : .blue,
                    trailing: AnyView(
                        permissionTrailing(isGranted: accessibilityGranted) {
                            HotkeyManager.requestAccessibilityPermissions()
                        }
                    )
                )
                .animation(.spring(duration: 0.3), value: accessibilityGranted)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            VStack(spacing: 8) {
                OnboardingButton(
                    label: "Continue",
                    style: bothGranted ? .primary : .disabled,
                    action: onContinue
                )

                if !bothGranted {
                    Text("Grant both permissions to continue")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func permissionTrailing(isGranted: Bool, onGrant: @escaping () -> Void) -> some View {
        if isGranted {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        } else {
            Button("Grant", action: onGrant)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

// MARK: - Step 5: AI Setup

private struct AISetupStep: View {
    @Binding var selectedProvider: CloudProvider
    @Binding var apiKeyInput: String
    @Binding var apiKeySaved: Bool
    let keychain: KeychainService
    let onFinish: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: OnboardingStyle.sectionSpacing) {
            OnboardingTitle(
                title: "Set Up Your AI",
                subtitle: "Choose a cloud provider for transcription"
            )
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            VStack(spacing: 16) {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(CloudProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(selectedProvider.displayName) API Key")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        SecureField("Paste your API key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))

                        Button {
                            try? keychain.save(account: selectedProvider.rawValue, value: apiKeyInput)
                            withAnimation(.spring(duration: 0.3)) {
                                apiKeySaved = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { apiKeySaved = false }
                            }
                        } label: {
                            Text(apiKeySaved ? "Saved!" : "Save")
                                .frame(width: 56)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(apiKeyInput.isEmpty)
                    }

                    Link("Get \(selectedProvider.displayName) API Key →", destination: selectedProvider.apiKeyURL)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.blue)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            VStack(spacing: 8) {
                OnboardingButton(label: "Finish Setup", action: onFinish)

                OnboardingButton(label: "Skip for Now", style: .text, action: onSkip)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                appeared = true
            }
        }
        .onChange(of: selectedProvider) {
            apiKeyInput = (try? keychain.retrieve(account: selectedProvider.rawValue)) ?? ""
            apiKeySaved = false
        }
    }
}

// MARK: - Use Case Chip

private struct UseCaseChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color.black.opacity(0.05)),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animated Gradient Background

private struct AnimatedGradientBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let blobs: [(Color, Double, Double, Double)] = [
                    (.blue.opacity(0.15), 0.3, 0.4, 1.0),
                    (.purple.opacity(0.12), 0.7, 0.3, 1.3),
                    (.cyan.opacity(0.10), 0.5, 0.7, 0.8),
                    (.indigo.opacity(0.08), 0.2, 0.6, 1.1),
                ]

                // Base fill
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(white: 0.97),
                            Color(white: 0.94)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                for (color, baseX, baseY, speed) in blobs {
                    let x = size.width * (baseX + 0.08 * sin(t * speed * 0.5))
                    let y = size.height * (baseY + 0.06 * cos(t * speed * 0.4))
                    let radius = min(size.width, size.height) * 0.4

                    let rect = CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [color, color.opacity(0)]),
                            center: CGPoint(x: x, y: y),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
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
