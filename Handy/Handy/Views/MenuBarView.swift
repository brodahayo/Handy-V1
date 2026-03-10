import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let onToggle: () -> Void
    let onQuit: () -> Void

    var body: some View {
        Button(appState.isRecording ? "Stop Recording" : "Start Recording") {
            onToggle()
        }
        .keyboardShortcut("r")

        Divider()

        if appState.isProcessing {
            Text("Processing...")
                .foregroundStyle(.secondary)
        }

        if let error = appState.errorMessage {
            Text(error)
                .foregroundStyle(.red)
        }

        Divider()

        SettingsLink {
            Text("Settings...")
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Handy") {
            onQuit()
        }
        .keyboardShortcut("q")
    }
}
