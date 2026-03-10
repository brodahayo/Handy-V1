import SwiftUI

struct SoundSettingsView: View {
    @Bindable var appState: AppState
    let soundPlayer = SoundPlayer()

    var body: some View {
        Form {
            Section("Sound Effects") {
                Toggle("Enable Sounds", isOn: $appState.settings.soundEnabled)

                if appState.settings.soundEnabled {
                    Picker("Sound Pack", selection: $appState.settings.soundPack) {
                        ForEach(SoundPack.allCases) { pack in
                            Text(pack.displayName).tag(pack)
                        }
                    }

                    HStack {
                        Button("Preview Start") {
                            soundPlayer.play(pack: appState.settings.soundPack, isStart: true, enabled: true)
                        }
                        .modifier(GlassButtonModifier())
                        .controlSize(.small)

                        Button("Preview Stop") {
                            soundPlayer.play(pack: appState.settings.soundPack, isStart: false, enabled: true)
                        }
                        .modifier(GlassButtonModifier())
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
