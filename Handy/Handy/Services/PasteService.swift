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

        // Don't simulate Cmd+V if the target is Handy itself — no text field to paste into,
        // and the simulated key event causes the macOS system alert beep.
        if let app = targetApp, app.bundleIdentifier == Bundle.main.bundleIdentifier {
            print("[Handy] Target app is Handy itself — skipping Cmd+V simulation (text is on clipboard)")
            targetApp = nil
            return
        }

        // Re-activate the target app so Cmd+V lands in the right input field
        let app = targetApp
        targetApp = nil

        if let app {
            app.activate()
            print("[Handy] Re-activated target app: \(app.localizedName ?? "unknown")")
        }

        // Wait for the target app to become frontmost, then simulate Cmd+V.
        // We poll (up to ~1s) instead of a fixed delay so we don't fire too early
        // and hit Handy's own window — which causes the macOS system alert beep.
        let targetPID = app?.processIdentifier
        PasteService.waitForFrontmost(pid: targetPID) {
            PasteService.simulatePaste()
        }
    }

    /// Polls until the given PID is the frontmost app (or timeout), then calls completion.
    private static func waitForFrontmost(pid: pid_t?, attempts: Int = 0, completion: @escaping @Sendable () -> Void) {
        let maxAttempts = 10 // ~500ms total
        let interval = 0.05 // 50ms per check

        // If no target PID or the target is already frontmost, proceed
        if pid == nil || NSWorkspace.shared.frontmostApplication?.processIdentifier == pid || attempts >= maxAttempts {
            completion()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            waitForFrontmost(pid: pid, attempts: attempts + 1, completion: completion)
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand

        if let keyDown, let keyUp {
            keyDown.post(tap: .cgSessionEventTap)
            usleep(20_000) // 20ms between key down and key up
            keyUp.post(tap: .cgSessionEventTap)
            print("[Handy] Simulated Cmd+V paste")
        } else {
            print("[Handy] Failed to create CGEvent for paste")
        }
    }
}
