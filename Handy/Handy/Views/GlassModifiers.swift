import SwiftUI

/// Applies `.buttonStyle(.glassProminent)` on macOS 26+, falls back to `.borderedProminent` on older versions.
struct GlassProminentButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

/// Applies `.buttonStyle(.glass)` on macOS 26+, falls back to `.bordered` on older versions.
struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

/// Applies `.glassEffect(.regular, in: .capsule)` on macOS 26+, falls back to `.background(.fill.tertiary, in: Capsule())`.
struct GlassEffectCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.fill.tertiary, in: Capsule())
        }
    }
}
