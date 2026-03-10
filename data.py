"""Local data persistence for Handy.

Stores transcription history and usage stats per user in:
~/Library/Application Support/Handy/users/{user_id}/data.json
"""

import json
import os
from datetime import datetime, date

_BASE_DIR = os.path.expanduser("~/Library/Application Support/Handy")
_current_user_id = None


def set_user(user_id):
    """Set the current user ID. Call on login."""
    global _current_user_id
    _current_user_id = user_id


def clear_user():
    """Clear user on logout."""
    global _current_user_id
    _current_user_id = None


def _get_data_file():
    if _current_user_id:
        d = os.path.join(_BASE_DIR, "users", _current_user_id)
    else:
        d = _BASE_DIR
    return d, os.path.join(d, "data.json")

_DEFAULT_DATA = {
    "transcriptions": [],       # list of {id, text, raw_text, word_count, timestamp, date}
    "stats": {
        "total_words": 0,
        "total_transcriptions": 0,
        "total_seconds_saved": 0,  # estimated time saved (avg typing speed ~40wpm vs speaking)
        "longest_streak": 0,
        "current_streak": 0,
        "last_active_date": None,
    },
    "daily_words": {},  # {"2026-03-09": 154, ...}
    "user_name": "User",
}


def load() -> dict:
    """Load data from disk."""
    data_dir, data_file = _get_data_file()
    data = json.loads(json.dumps(_DEFAULT_DATA))  # deep copy defaults
    if os.path.exists(data_file):
        try:
            with open(data_file, "r") as f:
                saved = json.load(f)
            for key in _DEFAULT_DATA:
                if key in saved:
                    if isinstance(_DEFAULT_DATA[key], dict) and isinstance(saved[key], dict):
                        data[key].update(saved[key])
                    else:
                        data[key] = saved[key]
        except (json.JSONDecodeError, OSError):
            pass
    return data


def save(data: dict):
    """Persist data to disk."""
    data_dir, data_file = _get_data_file()
    os.makedirs(data_dir, exist_ok=True)
    with open(data_file, "w") as f:
        json.dump(data, f, indent=2)


def add_transcription(raw_text: str, cleaned_text: str) -> dict:
    """Add a transcription to history and update stats. Returns the new entry."""
    data = load()
    today = date.today().isoformat()
    word_count = len(cleaned_text.split())

    entry = {
        "id": len(data["transcriptions"]) + 1,
        "text": cleaned_text,
        "raw_text": raw_text,
        "word_count": word_count,
        "timestamp": datetime.now().isoformat(),
        "date": today,
    }

    # Prepend (newest first)
    data["transcriptions"].insert(0, entry)

    # Keep only last 500 transcriptions
    data["transcriptions"] = data["transcriptions"][:500]

    # Update daily words
    data["daily_words"][today] = data["daily_words"].get(today, 0) + word_count

    # Update stats
    stats = data["stats"]
    stats["total_words"] += word_count
    stats["total_transcriptions"] += 1
    # Estimate time saved: speaking ~150wpm, typing ~40wpm => saves ~110wpm worth of time
    # So each word saves about 60/110 = 0.545 seconds
    stats["total_seconds_saved"] += int(word_count * 0.545)

    # Update streak
    last_active = stats.get("last_active_date")
    if last_active:
        last_date = date.fromisoformat(last_active)
        delta = (date.today() - last_date).days
        if delta == 1:
            stats["current_streak"] += 1
        elif delta > 1:
            stats["current_streak"] = 1
        # delta == 0 means same day, streak unchanged
    else:
        stats["current_streak"] = 1

    stats["last_active_date"] = today
    stats["longest_streak"] = max(stats["longest_streak"], stats["current_streak"])

    save(data)
    return entry


def get_transcriptions(limit: int = 50) -> list:
    """Get recent transcriptions."""
    data = load()
    return data["transcriptions"][:limit]


def get_stats() -> dict:
    """Get usage statistics."""
    data = load()
    return data["stats"]


def get_daily_words(days: int = 84) -> dict:
    """Get daily word counts for the last N days (default 84 = 12 weeks)."""
    data = load()
    today = date.today()
    result = {}
    for i in range(days):
        d = date.fromordinal(today.toordinal() - i)
        key = d.isoformat()
        result[key] = data["daily_words"].get(key, 0)
    return result


def get_today_words() -> int:
    """Get word count for today."""
    data = load()
    today = date.today().isoformat()
    return data["daily_words"].get(today, 0)


def get_user_name() -> str:
    """Get the user's display name."""
    data = load()
    return data.get("user_name", "User")


def set_user_name(name: str):
    """Set the user's display name."""
    data = load()
    data["user_name"] = name
    save(data)


def clear_history():
    """Clear all transcription history (keep stats)."""
    data = load()
    data["transcriptions"] = []
    save(data)
