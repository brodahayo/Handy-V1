import AppKit
import SwiftUI

final class RecordingOverlay {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<WaveformView>?

    func show(style: OverlayStyle, position: OverlayPosition, level: Float) {
        if panel == nil {
            createPanel(style: style, position: position)
        }
        updateLevel(level, style: style)
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
        let barCount = style == .mini ? 7 : 9
        let view = WaveformView(level: level, barCount: barCount, style: style)
        if let hostingView {
            hostingView.rootView = view
        }
    }

    private func createPanel(style: OverlayStyle, position: OverlayPosition) {
        let size: NSSize = style == .mini ? NSSize(width: 170, height: 42) : NSSize(width: 220, height: 52)

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

        let barCount = style == .mini ? 7 : 9
        let waveformView = WaveformView(level: 0, barCount: barCount, style: style)
        let hosting = NSHostingView(rootView: waveformView)
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
