import AppKit
import CoreGraphics

final class PasteService {

    /// The app that was frontmost when recording started — paste targets this app.
    private var targetApp: NSRunningApplication?

    /// Call when recording starts to snapshot the currently focused app.
    @MainActor
    func captureTargetApp() {
        targetApp = NSWorkspace.shared.frontmostApplication
        print("[Handy] Captured target app: \(targetApp?.localizedName ?? "none") (pid: \(targetApp?.processIdentifier ?? 0))")
    }

    @MainActor
    func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let verified = pasteboard.string(forType: .string) == text
        print("[Handy] Text copied to clipboard (\(text.count) chars, verified: \(verified))")

        // Check accessibility before attempting paste simulation
        guard AXIsProcessTrusted() else {
            print("[Handy] ⚠️ Accessibility not granted — text copied to clipboard but cannot simulate Cmd+V. Enable Handy in System Settings → Privacy & Security → Accessibility.")
            targetApp = nil
            return
        }

        // Re-activate the target app so Cmd+V lands in the right input field
        if let app = targetApp {
            app.activate()
            print("[Handy] Re-activated target app: \(app.localizedName ?? "unknown")")
        }

        // Delay to let the target app come to front, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            PasteService.simulatePaste()
        }

        targetApp = nil
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand

        if let keyDown, let keyUp {
            keyDown.post(tap: .cghidEventTap)
            usleep(20_000) // 20ms between key down and key up
            keyUp.post(tap: .cghidEventTap)
            print("[Handy] Simulated Cmd+V paste")
        } else {
            print("[Handy] Failed to create CGEvent for paste")
        }
    }
}
