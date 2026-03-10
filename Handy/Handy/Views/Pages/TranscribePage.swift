import SwiftUI

struct TranscribePage: View {
    let appState: AppState
    let onToggle: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Mic button — reuses the animated RecordButton from HomePage
            RecordButton(isRecording: appState.isRecording, action: onToggle)

            VStack(spacing: 4) {
                Text(appState.isRecording ? "Recording... Tap to stop" : "Tap to start recording")
                    .font(.headline)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: appState.isRecording)

                Text("Or use your hotkey")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Engine badge
                Text(engineLabel)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .modifier(GlassEffectCapsuleModifier())
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            // Audio level bars
            if appState.isRecording {
                AudioLevelBars(level: appState.audioLevel)
                    .padding(.top, 8)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // Processing state
            if appState.isProcessing {
                ProcessingBanner()
                    .padding(.horizontal, 40)
            }

            // Last transcription
            if let text = appState.lastTranscription {
                GroupBox("Last Transcription") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(text)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        HStack {
                            Text("\(text.split(separator: " ").count) words")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                                withAnimation(.spring(duration: 0.3)) {
                                    copied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { copied = false }
                                }
                            } label: {
                                Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .foregroundStyle(copied ? .green : .accentColor)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .animation(.spring(duration: 0.35, bounce: 0.2), value: appState.isRecording)
        .animation(.spring(duration: 0.3), value: appState.isProcessing)
        .animation(.spring(duration: 0.3), value: appState.lastTranscription)
    }

    private var engineLabel: String {
        switch appState.settings.transcriptionMode {
        case .cloud: "Cloud \u{00B7} \(appState.settings.cloudProvider.displayName)"
        case .local: "Local \u{00B7} \(appState.settings.localModelSize)"
        case .auto: "Auto \u{00B7} \(appState.settings.cloudProvider.displayName)"
        }
    }
}
