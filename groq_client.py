"""Groq API client for speech-to-text and AI text cleanup."""

import io
import wave
import requests
import numpy as np
from config import (
    GROQ_API_KEY, WHISPER_MODEL, LLM_MODEL,
    CLEANUP_PROMPT, SAMPLE_RATE, CHANNELS
)


GROQ_TRANSCRIPTION_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions"


def audio_to_wav_bytes(audio_frames, sample_rate=SAMPLE_RATE, channels=CHANNELS):
    """Convert raw audio frames to WAV bytes."""
    audio_data = np.concatenate(audio_frames)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(sample_rate)
        wf.writeframes(audio_data.tobytes())
    buf.seek(0)
    return buf


def transcribe(audio_frames, language="auto"):
    """Send audio to Groq Whisper and return transcribed text.

    Args:
        audio_frames: List of numpy int16 audio arrays.
        language: ISO 639-1 code ("en", "es", etc.) or "auto" for auto-detect.
    """
    if not GROQ_API_KEY:
        return "[ERROR] Set your GROQ_API_KEY in config.py"

    wav_buf = audio_to_wav_bytes(audio_frames)

    data = {
        "model": WHISPER_MODEL,
        "response_format": "text",
    }
    # Only pass language if not auto-detect (Whisper auto-detects when omitted)
    if language and language != "auto":
        data["language"] = language

    resp = requests.post(
        GROQ_TRANSCRIPTION_URL,
        headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
        files={"file": ("recording.wav", wav_buf, "audio/wav")},
        data=data,
        timeout=30,
    )

    if resp.status_code != 200:
        return f"[Transcription Error {resp.status_code}] {resp.text}"

    return resp.text.strip()


def cleanup_text(raw_text, prompt=None):
    """Use Groq LLM to clean up transcribed text.

    Args:
        raw_text: The raw transcription to clean up.
        prompt: Optional prompt template with a {text} placeholder.
                Falls back to CLEANUP_PROMPT from config if not provided.
    """
    if not GROQ_API_KEY:
        return raw_text
    if not raw_text or raw_text.startswith("["):
        return raw_text

    template = prompt if prompt else CLEANUP_PROMPT
    prompt = template.format(text=raw_text)

    resp = requests.post(
        GROQ_CHAT_URL,
        headers={
            "Authorization": f"Bearer {GROQ_API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "model": LLM_MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.3,
            "max_tokens": 2048,
        },
        timeout=30,
    )

    if resp.status_code != 200:
        return raw_text  # Fall back to raw transcription

    return resp.json()["choices"][0]["message"]["content"].strip()
