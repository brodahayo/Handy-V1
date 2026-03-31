import SwiftUI

struct MeetingNotesPage: View {
    let appState: AppState
    let onToggleRecording: () -> Void
    @State private var notesText = ""
    @State private var duration: TimeInterval = 0
    @State private var durationTimer: Timer?
    @State private var saveDebounce: Timer?

    private static var notesFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handy")
            .appendingPathComponent("meeting-notes.txt")
    }

    var wordCount: Int {
        notesText.split(separator: " ").count
    }

    var paragraphCount: Int {
        let paragraphs = notesText.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return max(paragraphs.count, notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Record button — hero element
            VStack(spacing: 12) {
                Button(action: onToggleRecording) {
                    ZStack {
                        if appState.isMeetingRecording {
                            Circle()
                                .stroke(Color.red.opacity(0.15), lineWidth: 1.5)
                                .frame(width: 64, height: 64)
                                .scaleEffect(1.4)
                                .opacity(0)
                                .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: appState.isMeetingRecording)
                        }

                        Circle()
                            .fill(appState.isMeetingRecording ? Color.red : (appState.isMeetingProcessing ? Color.orange : Color.accentColor))
                            .frame(width: 48, height: 48)
                            .shadow(color: (appState.isMeetingRecording ? Color.red : Color.accentColor).opacity(0.3), radius: 12, y: 4)

                        if appState.isMeetingProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: appState.isMeetingRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)
                .disabled(appState.isMeetingProcessing)

                if appState.isMeetingRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text(formatDuration(duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                } else if appState.isMeetingProcessing {
                    ProcessingBanner(compact: true)
                        .transition(.opacity)
                } else {
                    Text("Tap to capture meeting notes")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, notesText.isEmpty ? 40 : 20)
            .animation(.spring(duration: 0.3), value: appState.isMeetingRecording)
            .animation(.spring(duration: 0.3), value: appState.isMeetingProcessing)
            .onChange(of: appState.isMeetingRecording) {
                if appState.isMeetingRecording {
                    duration = 0
                    durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        DispatchQueue.main.async { duration += 1 }
                    }
                } else {
                    durationTimer?.invalidate()
                    durationTimer = nil
                }
            }

            // Editor — only visible when there are notes
            if !notesText.isEmpty || appState.isMeetingRecording || appState.isMeetingProcessing {
                TextEditor(text: $notesText)
                    .font(.body)
                    .frame(maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .onChange(of: notesText) {
                        saveDebounce?.invalidate()
                        saveDebounce = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            DispatchQueue.main.async { saveNotes() }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                // Bottom bar — actions + stats
                HStack(spacing: 8) {
                    Text("\(wordCount) words")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("\u{00B7}")
                        .font(.caption)
                        .foregroundStyle(.quaternary)

                    Text("\(paragraphCount) paragraphs")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    CopyButton(text: notesText, compact: true)

                    ToolbarTextButton(label: "Export") {
                        exportNotes()
                    }

                    ToolbarTextButton(label: "Clear") {
                        withAnimation(.spring(duration: 0.3)) {
                            notesText = ""
                            saveNotes()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .transition(.opacity)
            } else {
                Spacer()
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: notesText.isEmpty)
        .onAppear { loadNotes() }
        .onReceive(NotificationCenter.default.publisher(for: .meetingNoteTranscribed)) { notification in
            if let text = notification.userInfo?["text"] as? String {
                if notesText.isEmpty {
                    notesText = text
                } else {
                    notesText += "\n\n" + text
                }
                saveNotes()
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func exportNotes() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "meeting-notes.txt"
        if panel.runModal() == .OK, let url = panel.url {
            try? notesText.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func loadNotes() {
        guard FileManager.default.fileExists(atPath: Self.notesFileURL.path) else { return }
        notesText = (try? String(contentsOf: Self.notesFileURL, encoding: .utf8)) ?? ""
    }

    private func saveNotes() {
        do {
            let dir = Self.notesFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try notesText.write(to: Self.notesFileURL, atomically: true, encoding: .utf8)
        } catch {
            // Save failed — non-critical
        }
    }
}

// MARK: - Text-Only Toolbar Button with Hover State

private struct ToolbarTextButton: View {
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(isHovered ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.08) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
