"""Detect the frontmost macOS application and map it to a cleanup style."""

from AppKit import NSWorkspace

# Bundle ID -> cleanup style mapping
BUNDLE_STYLE_MAP = {
    # Professional
    "com.apple.mail": "professional",
    "com.microsoft.Outlook": "professional",
    # Casual messaging
    "com.apple.MobileSMS": "casual",
    "com.tinyspeck.slackmacgap": "casual",
    "com.discord.Discord": "casual",
    # Terminal / command
    "com.apple.Terminal": "command",
    "com.googlecode.iterm2": "command",
    "com.mitchellh.ghostty": "command",
    "net.kovidgoyal.kitty": "command",
    # Notes / writing
    "com.apple.Notes": "casual",
    "com.apple.Pages": "casual",
}

CONTEXT_PROMPTS = {
    "command": (
        "Convert the following spoken text into a clean terminal command. "
        "Output ONLY the command, no explanation or markdown."
    ),
}


def get_frontmost_app():
    """Return info about the frontmost app including its cleanup style."""
    app = NSWorkspace.sharedWorkspace().frontmostApplication()
    bundle_id = app.bundleIdentifier() or ""
    name = app.localizedName() or ""
    return {
        "bundle_id": bundle_id,
        "name": name,
        "cleanup_style": BUNDLE_STYLE_MAP.get(bundle_id),
    }
