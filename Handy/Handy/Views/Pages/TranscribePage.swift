import SwiftUI

struct TranscribePage: View {
    let appState: AppState
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Center area: hero result or recording visualization
            Spacer()

            if appState.isRecording {
                // Fluid wave visualizer when recording
                VStack(spacing: 0) {
                    Text("Listening...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)

                    FluidWaveVisualizer(level: appState.audioLevel)
                }
                .transition(.opacity)
            } else if appState.isProcessing {
                ProcessingBanner()
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            } else if let text = appState.lastTranscription {
                // Hero result text
                VStack(spacing: 12) {
                    Text(text)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .textSelection(.enabled)

                    // Word count + copy button
                    HStack(spacing: 12) {
                        Text("\(text.split(separator: " ").count) words")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        CopyButton(text: text)
                    }
                }
                .padding(.horizontal, 24)
                .transition(.opacity)
            } else {
                // Placeholder
                Text("Tap to start dictating")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .transition(.opacity)
            }

            Spacer()

            // Bottom pill strip
            HStack(spacing: 0) {
                // Left: status text
                if appState.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("Listening...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                } else if appState.isProcessing {
                    HStack(spacing: 6) {
                        SpinnerView(size: 12)
                        Text("Transcribing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                } else {
                    Text("Hold ")
                        .font(.subheadline)
                        .foregroundStyle(.quaternary)
                    + Text("Fn")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tertiary)
                    + Text(" to dictate")
                        .font(.subheadline)
                        .foregroundStyle(.quaternary)
                }

                Spacer()

                // Right: engine label + record button
                Text(engineLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 8)

                RecordButton(isRecording: appState.isRecording, action: onToggle)
            }
            .padding(.leading, 20)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(.quaternary.opacity(0.2))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.quaternary.opacity(0.15), lineWidth: 1)
            )
            .animation(.spring(duration: 0.3, bounce: 0.15), value: appState.isRecording)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
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
