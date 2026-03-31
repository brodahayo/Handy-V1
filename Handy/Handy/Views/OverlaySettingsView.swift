import SwiftUI

struct OverlaySettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section("Recording Window") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Style")
                        .font(.body.weight(.medium))

                    HStack(spacing: 16) {
                        OverlayStyleCard(
                            style: .classic,
                            label: "Classic",
                            isSelected: appState.settings.overlayStyle == .classic
                        ) {
                            appState.settings.overlayStyle = .classic
                        }

                        OverlayStyleCard(
                            style: .mini,
                            label: "Mini",
                            isSelected: appState.settings.overlayStyle == .mini
                        ) {
                            appState.settings.overlayStyle = .mini
                        }

                        OverlayStyleCard(
                            style: .none,
                            label: "None",
                            isSelected: appState.settings.overlayStyle == .none
                        ) {
                            appState.settings.overlayStyle = .none
                        }
                    }
                }
            }

            if appState.settings.overlayStyle != .none {
                Section("Position") {
                    Picker("Position", selection: $appState.settings.overlayPosition) {
                        Text("Top Center").tag(OverlayPosition.topCenter)
                        Text("Top Left").tag(OverlayPosition.topLeft)
                        Text("Top Right").tag(OverlayPosition.topRight)
                        Text("Bottom Center").tag(OverlayPosition.bottomCenter)
                        Text("Bottom Left").tag(OverlayPosition.bottomLeft)
                        Text("Bottom Right").tag(OverlayPosition.bottomRight)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct OverlayStyleCard: View {
    let style: OverlayStyle
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.06 : (isHovered ? 0.04 : 0.03)))
                    .frame(width: 120, height: 72)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.04),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
                    .overlay {
                        if style == .none {
                            Text("Off")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.quaternary)
                        } else {
                            OverlayPillPreview(style: style, animate: isHovered || isSelected)
                        }
                    }

                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .tertiary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct OverlayPillPreview: View {
    let style: OverlayStyle
    var animate: Bool = false

    private let barCount = 5
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.25)
                    .fill(.white.opacity(0.7))
                    .frame(width: 2.5, height: animatedBarHeight(for: index))
            }
        }
        .padding(.horizontal, style == .mini ? 16 : 20)
        .padding(.vertical, style == .mini ? 7 : 8)
        .frame(height: style == .mini ? 26 : 32)
        .background(
            Capsule()
                .fill(Color(white: 0.08, opacity: 0.9))
        )
        .onChange(of: animate) {
            if animate {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    phase = 0
                }
            }
        }
    }

    private func animatedBarHeight(for index: Int) -> CGFloat {
        let baseHeights: [CGFloat] = style == .mini
            ? [6, 10, 14, 10, 6]
            : [8, 14, 20, 14, 8]
        let base = index < baseHeights.count ? baseHeights[index] : 8
        // Animate bars with a wave offset per bar
        let offset = sin(Double(index) * 0.8 + Double(phase) * .pi) * 3.0
        return base + CGFloat(offset) * phase
    }
}

