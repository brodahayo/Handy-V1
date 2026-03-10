import SwiftUI

struct ModelsPage: View {
    @Bindable var appState: AppState
    let keychain: KeychainService

    @State private var apiKeyInput = ""

    private static let models: [(name: String, size: String, detail: String, fileSize: String)] = [
        ("Tiny", "tiny", "Fastest, lowest accuracy", "74 MB"),
        ("Tiny (English)", "tiny.en", "English-only, slightly better", "74 MB"),
        ("Base", "base", "Good balance of speed and accuracy", "141 MB"),
        ("Base (English)", "base.en", "English-only base model", "141 MB"),
        ("Small", "small", "Higher accuracy, slower", "465 MB"),
        ("Small (English)", "small.en", "English-only small model", "465 MB"),
        ("Medium", "medium", "High accuracy", "1.5 GB"),
        ("Medium (English)", "medium.en", "English-only medium model", "1.5 GB"),
        ("Large v3", "large-v3", "Best accuracy, slowest", "3 GB"),
    ]

    var body: some View {
        Form {
            Section("Cloud Provider") {
                Picker("Provider", selection: $appState.settings.cloudProvider) {
                    ForEach(CloudProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                LabeledContent("API Key") {
                    HStack {
                        SecureField("API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") {
                            try? keychain.save(account: appState.settings.cloudProvider.rawValue, value: apiKeyInput)
                        }
                        .modifier(GlassProminentButtonModifier())
                        .controlSize(.small)
                    }
                }

                Link("Get API Key", destination: appState.settings.cloudProvider.apiKeyURL)
                    .font(.caption)
            }

            Section("Engine") {
                Picker("Mode", selection: $appState.settings.transcriptionMode) {
                    Text("Cloud").tag(TranscriptionMode.cloud)
                    Text("Local").tag(TranscriptionMode.local)
                    Text("Auto").tag(TranscriptionMode.auto)
                }

                Text("Download local Whisper models for offline transcription. Larger models are more accurate but slower.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Local Models") {
                ForEach(Self.models, id: \.size) { model in
                    modelRow(model)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            apiKeyInput = (try? keychain.retrieve(account: appState.settings.cloudProvider.rawValue)) ?? ""
        }
        .onChange(of: appState.settings.cloudProvider) {
            apiKeyInput = (try? keychain.retrieve(account: appState.settings.cloudProvider.rawValue)) ?? ""
        }
    }

    @ViewBuilder
    private func modelRow(_ model: (name: String, size: String, detail: String, fileSize: String)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.body.weight(.medium))

                    if LocalTranscriber.isModelDownloaded(model.size) {
                        Text("Downloaded")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }

                    if appState.settings.localModelSize == model.size {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text("\(model.detail) — \(model.fileSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if LocalTranscriber.isModelDownloaded(model.size) {
                Button("Use") {
                    appState.settings.localModelSize = model.size
                }
                .disabled(appState.settings.localModelSize == model.size)
                .controlSize(.small)
            } else {
                Button("Download") {
                    // TODO: download model
                }
                .modifier(GlassProminentButtonModifier())
                .controlSize(.small)
            }
        }
    }
}
