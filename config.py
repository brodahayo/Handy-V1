# Voice Command Configuration
# API key loaded from environment variable or settings.
# Set GROQ_API_KEY in your shell profile, or enter it in the app's Settings page.
import os

GROQ_API_KEY = ""  # Users enter their own key in Settings

# Audio settings
SAMPLE_RATE = 16000
CHANNELS = 1
CHUNK_SIZE = 1024

# Groq models
WHISPER_MODEL = "whisper-large-v3"
LLM_MODEL = "llama-3.3-70b-versatile"

# Hotkey: Option (Alt) + V to toggle recording
HOTKEY_MODIFIER = "alt"
HOTKEY_KEY = "v"

# AI cleanup prompt
CLEANUP_PROMPT = """You are a voice-to-text assistant. Clean up the following transcribed speech into well-written text.

Rules:
- Fix grammar, punctuation, and capitalization
- Remove filler words (um, uh, like, you know) unless they add meaning
- Keep the original meaning and tone
- Do NOT add information that wasn't spoken
- Do NOT add any preamble or explanation, just output the cleaned text
- If the text is a command or short phrase, keep it short
- Match the formality level of the original speech

Transcribed speech:
{text}

Cleaned text:"""
