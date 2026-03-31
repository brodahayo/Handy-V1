import SwiftUI

struct ModelsPage: View {
    @Bindable var appState: AppState
    let keychain: KeychainService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Provider selection
                ProviderSection(appState: appState)

                // API Key
                APIKeySection(appState: appState, keychain: keychain)

                Divider().opacity(0.5)

                // Local models coming soon
                ComingSoonBanner()
            }
            .padding(20)
        }
    }
}

// MARK: - Provider Selection

private struct ProviderSection: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Provider")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(CloudProvider.allCases) { provider in
                    ProviderCard(
                        provider: provider,
                        isSelected: appState.settings.cloudProvider == provider
                    ) {
                        appState.settings.cloudProvider = provider
                    }
                }
            }
        }
    }
}

// MARK: - API Key

private struct APIKeySection: View {
    @Bindable var appState: AppState
    let keychain: KeychainService

    @State private var apiKeyInput = ""
    @State private var isEditingKey = false
    @State private var keySaved = false

    private var hasStoredKey: Bool {
        let key = (try? keychain.retrieve(account: appState.settings.cloudProvider.rawValue)) ?? ""
        return !key.isEmpty
    }

    private var maskedKey: String {
        let key = (try? keychain.retrieve(account: appState.settings.cloudProvider.rawValue)) ?? ""
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        return String(key.prefix(4)) + "••••" + String(key.suffix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            apiKeyHeader
            if isEditingKey {
                apiKeyEditor
            } else {
                apiKeyDisplay
            }
        }
        .onChange(of: appState.settings.cloudProvider) {
            apiKeyInput = ""
            keySaved = false
            isEditingKey = false
        }
    }

    private var apiKeyHeader: some View {
        HStack {
            Text("API Key")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Link(destination: appState.settings.cloudProvider.apiKeyURL) {
                HStack(spacing: 4) {
                    Text("Get a key")
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                }
                .font(.caption)
            }
        }
    }

    private var apiKeyEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Paste your API key here", text: $apiKeyInput)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Button {
                    guard !apiKeyInput.isEmpty else { return }
                    try? keychain.save(account: appState.settings.cloudProvider.rawValue, value: apiKeyInput)
                    apiKeyInput = ""
                    withAnimation(.spring(duration: 0.3)) {
                        keySaved = true
                        isEditingKey = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { keySaved = false }
                    }
                } label: {
                    Text("Save Key")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    apiKeyInput = ""
                    withAnimation(.spring(duration: 0.2)) { isEditingKey = false }
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity)
    }

    private var apiKeyDisplay: some View {
        HStack(spacing: 10) {
            keyStatusLabel
            Spacer()
            changeKeyButton
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private var keyStatusLabel: some View {
        if hasStoredKey {
            HStack(spacing: 6) {
                Image(systemName: keySaved ? "checkmark.circle.fill" : "key.fill")
                    .foregroundStyle(keySaved ? .green : .secondary)
                    .font(.caption)
                    .contentTransition(.symbolEffect(.replace))
                Text(keySaved ? "Key saved" : maskedKey)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(keySaved ? .green : .secondary)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("No key configured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var changeKeyButton: some View {
        Button {
            apiKeyInput = ""
            withAnimation(.spring(duration: 0.2)) { isEditingKey = true }
        } label: {
            Text(hasStoredKey ? "Change" : "Add Key")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(hasStoredKey ? Color.secondary : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    hasStoredKey
                        ? AnyShapeStyle(Color.primary.opacity(0.06))
                        : AnyShapeStyle(Color.accentColor),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coming Soon Banner

private struct ComingSoonBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "desktopcomputer")
                .font(.title2)
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Local Models — Coming Soon")
                    .font(.subheadline.weight(.medium))
                Text("On-device transcription with Whisper will be available in a future update.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Provider Card

private struct ProviderCard: View {
    let provider: CloudProvider
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var icon: String {
        switch provider {
        case .groq: "bolt.fill"
        case .openai: "brain"
        case .deepgram: "waveform"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text(provider.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(isHovered ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }
}
