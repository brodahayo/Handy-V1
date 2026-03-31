import SwiftUI

struct CleanupSettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section("AI Text Cleanup") {
                Toggle("Enable Cleanup", isOn: $appState.settings.cleanupEnabled)

                if appState.settings.cleanupEnabled {
                    Picker("Style", selection: $appState.settings.cleanupStyle) {
                        ForEach(CleanupStyle.allCases) { style in
                            VStack(alignment: .leading) {
                                Text(style.displayName)
                            }
                            .tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Toggle("Context-Aware (detect app type)", isOn: $appState.settings.contextAware)
                }
            }
        }
        .formStyle(.grouped)
    }
}
