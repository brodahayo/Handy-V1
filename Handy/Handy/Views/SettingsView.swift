import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    let keychain: KeychainService

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                HotkeySettingsView(appState: appState)
            }

            Tab("Transcription", systemImage: "waveform") {
                TranscriptionSettingsView(appState: appState, keychain: keychain)
            }

            Tab("Cleanup", systemImage: "text.badge.checkmark") {
                CleanupSettingsView(appState: appState)
            }

            Tab("Overlay", systemImage: "rectangle.on.rectangle") {
                OverlaySettingsView(appState: appState)
            }

            Tab("Sounds", systemImage: "speaker.wave.2") {
                SoundSettingsView(appState: appState)
            }

            Tab("Account", systemImage: "person.circle") {
                AccountView(appState: appState)
            }
        }
        .scenePadding()
        .frame(minWidth: 500, idealWidth: 550, minHeight: 400, idealHeight: 450)
    }
}
