"""Version and update checking for Handy."""

import json
import urllib.request
import urllib.error

APP_VERSION = "1.0.0"
APP_NAME = "Handy"

# URL that returns JSON: {"version": "1.1.0", "download_url": "https://...", "notes": "..."}
# Point this to your own endpoint (GitHub release API, raw JSON file, etc.)
UPDATE_CHECK_URL = "https://raw.githubusercontent.com/brodahayo/Handy/main/latest_version.json"


def check_for_updates() -> dict:
    """Check for a newer version of Handy.

    Returns:
        {
            "current": "1.0.0",
            "latest": "1.1.0",       # or same as current if up to date
            "update_available": True,
            "download_url": "https://...",
            "notes": "Bug fixes and improvements",
        }
    """
    result = {
        "current": APP_VERSION,
        "latest": APP_VERSION,
        "update_available": False,
        "download_url": "",
        "notes": "",
    }

    try:
        req = urllib.request.Request(
            UPDATE_CHECK_URL,
            headers={"User-Agent": f"Handy/{APP_VERSION}"},
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode("utf-8"))

        latest = data.get("version", APP_VERSION)
        result["latest"] = latest
        result["download_url"] = data.get("download_url", "")
        result["notes"] = data.get("notes", "")
        result["update_available"] = _version_newer(latest, APP_VERSION)

    except (urllib.error.URLError, json.JSONDecodeError, OSError, KeyError):
        pass

    return result


def _version_newer(latest: str, current: str) -> bool:
    """Compare semver strings. Returns True if latest > current."""
    try:
        l_parts = [int(x) for x in latest.split(".")]
        c_parts = [int(x) for x in current.split(".")]
        return l_parts > c_parts
    except (ValueError, AttributeError):
        return False
