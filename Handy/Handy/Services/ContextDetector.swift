import AppKit

enum ContextDetector {

    private static let bundleIdStyles: [String: CleanupStyle] = [
        "com.apple.mail": .professional,
        "com.microsoft.Outlook": .professional,
        "com.apple.MobileSMS": .casual,
        "com.tinyspeck.slackmacgap": .casual,
        "com.hnc.Discord": .casual,
        "com.apple.Notes": .casual,
        "com.apple.iWork.Pages": .casual,
        "com.apple.Terminal": .minimal,
        "com.googlecode.iterm2": .minimal,
        "com.mitchellh.ghostty": .minimal,
        "net.kovidgoyal.kitty": .minimal,
    ]

    static func cleanupStyle(forBundleId bundleId: String) -> CleanupStyle? {
        bundleIdStyles[bundleId]
    }

    static func detectFrontmostApp() -> (bundleId: String?, appName: String?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil)
        }
        return (app.bundleIdentifier, app.localizedName)
    }

    static func detectCleanupStyle() -> CleanupStyle? {
        guard let bundleId = detectFrontmostApp().bundleId else { return nil }
        return cleanupStyle(forBundleId: bundleId)
    }
}
