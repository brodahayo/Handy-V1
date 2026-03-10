<p align="center">
  <img src="assets/app-icon.svg" width="128" height="128" alt="Handy icon">
</p>

<h1 align="center">Handy</h1>

<p align="center">
  <strong>Speak naturally. Get clean text. Anywhere on your Mac.</strong>
</p>

<p align="center">
  Handy is a macOS menu bar app that turns your voice into polished, ready-to-use text — pasted directly where your cursor is. No copying, no switching windows, no friction.
</p>

<p align="center">
  <a href="https://github.com/brodahayo/Handy/releases/latest/download/Handy.dmg">
    <img src="https://img.shields.io/badge/Download-Handy.dmg-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Download">
  </a>
</p>

---

## What is Handy?

Handy sits quietly in your menu bar and listens when you need it. Hold a key, speak, release — your words appear as clean, formatted text wherever you're typing. Emails, Slack messages, code comments, documents. It just works.

Think of it as your personal stenographer that:
- **Hears** what you say (via Whisper speech-to-text)
- **Cleans** it up with AI (fixes grammar, removes filler words)
- **Pastes** the result right where your cursor is

No more typing the same long email. No more struggling to articulate a complex thought in text. Just speak it.

---

## Quick Tour

### Home
Your command center. See today's word count, track your daily goal, and browse your transcription history at a glance.

### Transcribe
The core of Handy. Hit your hotkey, speak, and watch your words get transcribed and cleaned up in real-time. Two modes:
- **Quick Dictation** — Hold a key (like `Fn`) to record, release to transcribe
- **Hands-Free Toggle** — Press a key combo (like `⌥V`) to start/stop recording

### Meeting Notes
Dedicated space for capturing meeting notes by voice. Record segments, review, edit, and export — all without leaving the app.

### Dictionary
Add custom words, names, and terminology that the AI should recognize and preserve. Technical jargon, product names, people's names — Handy learns your vocabulary.

### Settings
Fine-tune everything:
- **Cloud provider** — Groq (free), OpenAI, or Deepgram
- **Cleanup style** — Casual, Professional, or Minimal
- **Hotkeys** — Customize your recording triggers
- **Overlay** — Choose the recording indicator style and position
- **Sounds** — Pick your start/stop recording sound effects
- **Local models** — Download Whisper models for offline use

---

## Installation

1. **Download** [`Handy.dmg`](https://github.com/brodahayo/Handy/releases/latest/download/Handy.dmg)
2. **Open** the DMG and drag Handy to your Applications folder
3. **Launch** Handy from Applications
4. **First launch**: Right-click the app → Open (to bypass Gatekeeper since the app isn't notarized yet)
5. **Grant permissions** when prompted:
   - **Microphone** — so Handy can hear you
   - **Accessibility** — so Handy can paste text into your apps

## Setup

1. Create a free account or sign in
2. Go to **Settings** and enter your API key:
   - **Groq** (recommended, free): Get a key at [console.groq.com](https://console.groq.com)
   - **OpenAI**: Use your existing OpenAI key
   - **Deepgram**: Get a key at [deepgram.com](https://deepgram.com)
3. Start talking!

---

## How It Works

```
You speak → Whisper transcribes → LLM cleans up → Text is pasted
            (cloud or local)      (grammar, filler   (pbcopy + Cmd+V)
                                   words, formatting)
```

**Cloud mode** sends audio to your chosen provider for transcription. **Local mode** runs Whisper directly on your Mac — fully offline, no API key needed.

---

## System Requirements

- macOS 12.0 (Monterey) or later
- Microphone access
- Accessibility permission
- Internet connection (for cloud transcription) or downloaded local model (for offline)

---

## For Developers

### Running from source

```bash
# Install dependencies
brew install portaudio
pip3 install -r requirements.txt

# Run
python3 app.py
```

### Building the app

```bash
# Build .app bundle and DMG
chmod +x build_dmg.sh
./build_dmg.sh
```

### Releasing a new version

```bash
# 1. Update version in version.py and setup_app.py
# 2. Commit and tag
git add -A && git commit -m "Release v1.1.0"
git tag v1.1.0
git push origin main --tags
# 3. GitHub Actions builds the DMG and creates a release automatically
```

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| App framework | Python + pywebview + rumps (menu bar) |
| UI | HTML/CSS/JS (single-file, macOS-native aesthetic) |
| Speech-to-text | Whisper (via Groq/OpenAI/Deepgram or local faster-whisper) |
| Text cleanup | LLM (Llama 3.3 70B via Groq, or GPT via OpenAI) |
| Recording overlay | Native macOS NSWindow + NSView (PyObjC) |
| Auth | Supabase (email/password + Google OAuth) |
| Data storage | Local JSON files, per-user isolation |

---

<p align="center">
  Built with ❤️ by <a href="https://github.com/brodahayo">brodahayo</a>
</p>
