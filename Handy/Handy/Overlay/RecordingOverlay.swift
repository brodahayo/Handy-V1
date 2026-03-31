import AppKit
import SwiftUI

enum OverlayMode {
    case recording
    case processing
}

final class RecordingOverlay {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayContentView>?
    private var currentMode: OverlayMode = .recording

    func show(style: OverlayStyle, position: OverlayPosition, level: Float) {
        currentMode = .recording
        if panel == nil {
            createPanel(style: style, position: position)
        }
        updateLevel(level, style: style)
        panel?.orderFrontRegardless()
    }

    func showProcessing(style: OverlayStyle, position: OverlayPosition) {
        currentMode = .processing
        if panel == nil {
            createPanel(style: style, position: position)
        }
        let view = OverlayContentView(level: 0, style: style, mode: .processing)
        hostingView?.rootView = view
        panel?.orderFrontRegardless()
    }

    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
            self?.hostingView = nil
        }
    }

    func updateLevel(_ level: Float, style: OverlayStyle) {
        let view = OverlayContentView(level: level, style: style, mode: currentMode)
        hostingView?.rootView = view
    }

    private func createPanel(style: OverlayStyle, position: OverlayPosition) {
        let size: NSSize = style == .mini
            ? NSSize(width: 140, height: 36)
            : NSSize(width: 240, height: 52)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.alphaValue = 0

        let contentView = OverlayContentView(level: 0, style: style, mode: currentMode)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            var origin: NSPoint

            switch position {
            case .topCenter:
                origin = NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height - 10)
            case .topLeft:
                origin = NSPoint(x: screenFrame.minX + 20, y: screenFrame.maxY - size.height - 10)
            case .topRight:
                origin = NSPoint(x: screenFrame.maxX - size.width - 20, y: screenFrame.maxY - size.height - 10)
            case .bottomCenter:
                origin = NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.minY + 10)
            case .bottomLeft:
                origin = NSPoint(x: screenFrame.minX + 20, y: screenFrame.minY + 10)
            case .bottomRight:
                origin = NSPoint(x: screenFrame.maxX - size.width - 20, y: screenFrame.minY + 10)
            }
            panel.setFrameOrigin(origin)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        self.hostingView = hosting
    }
}

// MARK: - Overlay Content View

struct OverlayContentView: View {
    let level: Float
    let style: OverlayStyle
    let mode: OverlayMode

    private var barCount: Int { style == .mini ? 16 : 24 }
    private var maxBarHeight: CGFloat { style == .mini ? 16 : 24 }

    var body: some View {
        ZStack {
            // Base capsule
            Capsule()
                .fill(Color(white: 0.04, opacity: 0.92))

            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.1), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )

            if mode == .recording {
                recordingContent
            } else {
                overlayProcessingContent
            }
        }
    }

    // MARK: - Recording: EQ Bars + Red Dot

    private var recordingContent: some View {
        HStack(spacing: style == .mini ? 8 : 10) {
            // Red dot
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .shadow(color: .red.opacity(0.4), radius: 4)
                .modifier(PulseDotModifier())

            // EQ Bars
            HStack(spacing: style == .mini ? 2 : 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    OverlayEQBar(
                        index: index,
                        barCount: barCount,
                        level: level,
                        maxHeight: maxBarHeight
                    )
                }
            }
        }
        .padding(.horizontal, style == .mini ? 14 : 18)
    }

    // MARK: - Processing: Shimmer + Spinner

    private var overlayProcessingContent: some View {
        OverlayShimmerProcessing(style: style)
    }
}

// MARK: - EQ Bar

private struct OverlayEQBar: View {
    let index: Int
    let barCount: Int
    let level: Float
    let maxHeight: CGFloat

    @State private var animatedHeight: CGFloat = 3

    private var targetHeight: CGFloat {
        let center = Float(barCount) / 2.0
        let dist = abs(Float(index) - center) / center
        let bell = 1.0 - dist * dist
        let base: CGFloat = 3
        let audio = CGFloat(level) * CGFloat(bell) * maxHeight
        return max(base, base + audio)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.6),
                        Color(red: 0.35, green: 0.78, blue: 0.98).opacity(0.3)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 2.5, height: animatedHeight)
            .onChange(of: level) {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                    animatedHeight = targetHeight
                }
            }
            .onAppear { animatedHeight = targetHeight }
    }
}

// MARK: - Shimmer Processing Overlay

private struct OverlayShimmerProcessing: View {
    let style: OverlayStyle
    @State private var shimmerOffset: CGFloat = -1
    @State private var spinning = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    Color.accentColor.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: style == .mini ? 10 : 12, height: style == .mini ? 10 : 12)
                .rotationEffect(.degrees(spinning ? 360 : 0))
        }
        .overlay {
            // Shimmer sweep
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.accentColor.opacity(0.06), .clear],
                        startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
                        endPoint: UnitPoint(x: shimmerOffset + 0.5, y: 0.5)
                    )
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                spinning = true
            }
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.5
            }
        }
    }
}

// MARK: - Pulse Dot Modifier

private struct PulseDotModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing ? 0.4 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}
