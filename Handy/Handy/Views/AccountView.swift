import SwiftUI

struct AccountView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section("Account") {
                if appState.isSignedIn {
                    LabeledContent("Signed in as", value: appState.userName ?? "User")
                    Button("Sign Out") {
                        appState.isSignedIn = false
                        appState.userId = nil
                        appState.userName = nil
                    }
                } else {
                    Text("Sign in to sync your settings across devices.")
                        .foregroundStyle(.secondary)
                    Button("Sign In with Google") {
                        // TODO: SupabaseManager OAuth flow
                    }
                    .modifier(GlassButtonModifier())

                    Button("Sign In with GitHub") {
                        // TODO: SupabaseManager OAuth flow
                    }
                    .modifier(GlassButtonModifier())
                }
            }
        }
        .formStyle(.grouped)
    }
}
