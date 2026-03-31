import SwiftUI

enum SidebarPage: String, CaseIterable, Identifiable {
    case home = "Home"
    case transcribe = "Transcribe"
    case meetingNotes = "Meeting Notes"
    case dictionary = "Dictionary"
    case models = "Models"
    case settings = "Settings"

    var id: Self { self }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .transcribe: "mic.fill"
        case .meetingNotes: "doc.text.fill"
        case .dictionary: "character.book.closed.fill"
        case .models: "cpu.fill"
        case .settings: "gearshape.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .home: .blue
        case .transcribe: .red
        case .meetingNotes: .orange
        case .dictionary: .purple
        case .models: .gray
        case .settings: .gray
        }
    }
}

/// A macOS System Settings-style icon: a filled SF Symbol on a colored rounded rectangle.
struct SettingsIcon: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.55))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct MainWindowView: View {
    @Bindable var appState: AppState
    let onToggle: () -> Void
    let onMeetingToggle: () -> Void
    let keychain: KeychainService

    private var selectedPage: Binding<SidebarPage?> {
        Binding(
            get: { SidebarPage(rawValue: appState.selectedPage ?? "Home") ?? .home },
            set: { appState.selectedPage = $0?.rawValue ?? "Home" }
        )
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: selectedPage) {
                    ForEach(SidebarPage.allCases) { page in
                        Label {
                            Text(page.rawValue)
                        } icon: {
                            SettingsIcon(systemImage: page.icon, color: page.iconColor)
                        }
                        .tag(page)
                    }
                }
                .listStyle(.sidebar)

                HStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Handy")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Voice to Text")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detailView
                .id(appState.selectedPage)
                .navigationTitle(appState.selectedPage ?? "Home")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: appState.selectedPage)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var currentPage: SidebarPage {
        SidebarPage(rawValue: appState.selectedPage ?? "Home") ?? .home
    }

    @ViewBuilder
    private var detailView: some View {
        switch currentPage {
        case .home:
            HomePage(appState: appState, onToggle: onToggle)
        case .transcribe:
            TranscribePage(appState: appState, onToggle: onToggle)
        case .meetingNotes:
            MeetingNotesPage(appState: appState, onToggleRecording: onMeetingToggle)
        case .dictionary:
            DictionaryPage(appState: appState)
        case .models:
            ModelsPage(appState: appState, keychain: keychain)
        case .settings:
            SettingsPage(appState: appState)
        }
    }
}

#Preview {
    MainWindowView(
        appState: AppState(),
        onToggle: {},
        onMeetingToggle: {},
        keychain: KeychainService()
    )
}
