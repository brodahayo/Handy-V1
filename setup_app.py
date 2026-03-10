"""
py2app setup script for Handy.

Build with:
    python3 setup_app.py py2app
"""

from setuptools import setup

APP = ["app.py"]
DATA_FILES = [
    ("", ["ui.html"]),
    ("sounds", [
        "sounds/woody_start.wav",
        "sounds/woody_stop.wav",
    ]),
]

OPTIONS = {
    "argv_emulation": False,
    "iconfile": "Handy.icns",
    "plist": {
        "CFBundleName": "Handy",
        "CFBundleDisplayName": "Handy",
        "CFBundleIdentifier": "com.handy.app",
        "CFBundleVersion": "1.0.0",
        "CFBundleShortVersionString": "1.0.0",
        "LSMinimumSystemVersion": "12.0",
        "LSUIElement": True,  # Menu bar app — no dock icon
        "NSMicrophoneUsageDescription": "Handy needs microphone access to record your voice for transcription.",
        "NSAppleEventsUsageDescription": "Handy needs automation access to paste transcribed text into your active application.",
    },
    "packages": ["rumps", "pynput", "requests", "numpy", "certifi", "webview"],
    "includes": [
        "api",
        "config",
        "recorder",
        "cloud_transcribe",
        "local_whisper",
        "context_detect",
        "data",
        "version",
        "overlay",
        "statusbar",
        "sounds",
        "settings",
        "settings_window",
        "supabase_config",
        "groq_client",
        "pyaudio",
        "Cocoa",
        "Foundation",
        "AppKit",
        "objc",
        "PyObjCTools",
    ],
    "frameworks": ["/opt/homebrew/lib/libportaudio.dylib"],
}

setup(
    app=APP,
    data_files=DATA_FILES,
    options={"py2app": OPTIONS},
    setup_requires=["py2app"],
)
