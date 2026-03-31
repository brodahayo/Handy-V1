import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let onToggle: () -> Void
    let onQuit: () -> Void

    var body: some View {
        // Recording
        Button(appState.isRecording ? "Stop Recording" : "Start Recording") {
            onToggle()
        }
        .keyboardShortcut("r")

        if appState.isProcessing {
            Text("Transcribing...")
                .foregroundStyle(.secondary)
        }

        Divider()

        // Last transcription
        if let text = appState.lastTranscription {
            Button("Copy Last Transcription") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            .keyboardShortcut("c")
        }

        // Quick toggles
        Button(appState.settings.cleanupEnabled ? "Disable AI Cleanup" : "Enable AI Cleanup") {
            appState.settings.cleanupEnabled.toggle()
        }

        Button(appState.settings.soundEnabled ? "Mute Sounds" : "Unmute Sounds") {
            appState.settings.soundEnabled.toggle()
        }

        Divider()

        // Navigate to pages
        Menu("Open Page") {
            Button("Home") { navigateTo("Home") }
            Button("Transcribe") { navigateTo("Transcribe") }
            Button("Meeting Notes") { navigateTo("Meeting Notes") }
            Button("Dictionary") { navigateTo("Dictionary") }
            Button("Models") { navigateTo("Models") }
        }

        Button("Settings") {
            navigateTo("Settings")
        }
        .keyboardShortcut(",")

        Divider()

        // Stats
        Text("\(appState.todayWords) words today")
            .foregroundStyle(.secondary)

        if appState.currentStreak > 0 {
            Text("\(appState.currentStreak) day streak")
                .foregroundStyle(.secondary)
        }

        Divider()

        Button("Quit Handy") {
            onQuit()
        }
        .keyboardShortcut("q")
    }

    private func navigateTo(_ page: String) {
        appState.selectedPage = page
        // Bring main window to front
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.title != "" && !$0.title.starts(with: "Item-") }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
