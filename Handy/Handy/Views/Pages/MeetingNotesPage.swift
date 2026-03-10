import SwiftUI

struct MeetingNotesPage: View {
    let appState: AppState
    @State private var notesText = ""
    @State private var isNotesRecording = false
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?

    var wordCount: Int {
        notesText.split(separator: " ").count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                if isNotesRecording {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text("Recording — \(formatDuration(duration))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Press record to start capturing meeting notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(notesText, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    notesText = ""
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.borderless)

                Button {
                    isNotesRecording.toggle()
                    if isNotesRecording {
                        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
                            MainActor.assumeIsolated {
                                duration += 1
                            }
                        }
                    } else {
                        timer?.invalidate()
                        timer = nil
                    }
                } label: {
                    Label(
                        isNotesRecording ? "Stop" : "Record",
                        systemImage: isNotesRecording ? "stop.fill" : "mic.fill"
                    )
                }
                .modifier(GlassProminentButtonModifier())
                .tint(isNotesRecording ? .red : .accentColor)
                .controlSize(.small)
            }
            .padding(.bottom, 12)

            // Notes editor
            TextEditor(text: $notesText)
                .font(.body)
                .frame(maxHeight: .infinity)
                .border(Color(nsColor: .separatorColor))
                .scrollContentBackground(.visible)

            // Footer
            HStack {
                Text("\(wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Export...") {
                    exportNotes()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.top, 8)
        }
        .padding()
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
}
