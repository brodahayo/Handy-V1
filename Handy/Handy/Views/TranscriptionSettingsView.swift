import SwiftUI

struct TranscriptionSettingsView: View {
    @Bindable var appState: AppState
    let keychain: KeychainService
    @State private var apiKeyInput = ""

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
                            try? keychain.save(
                                account: appState.settings.cloudProvider.rawValue,
                                value: apiKeyInput
                            )
                        }
                        .modifier(GlassProminentButtonModifier())
                        .controlSize(.small)
                    }
                }

                Link("Get API Key →", destination: appState.settings.cloudProvider.apiKeyURL)
                    .foregroundStyle(.blue)
            }

            Section("Language") {
                Picker("Language", selection: $appState.settings.language) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
            }

            Section("Transcription Mode") {
                Picker("Mode", selection: $appState.settings.transcriptionMode) {
                    Text("Cloud").tag(TranscriptionMode.cloud)
                    Text("Local (Offline)").tag(TranscriptionMode.local)
                    Text("Auto (cloud first, local fallback)").tag(TranscriptionMode.auto)
                }
                .pickerStyle(.radioGroup)
            }

            if appState.settings.transcriptionMode != .cloud {
                Section("Offline Models") {
                    ModelManagerView()
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
}
