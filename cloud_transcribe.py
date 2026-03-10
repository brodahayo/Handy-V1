"""Cloud transcription providers — Groq, OpenAI, Deepgram."""

import io
import wave
import requests
import numpy as np
from config import SAMPLE_RATE, CHANNELS


# ── Provider registry ────────────────────────────────────────────────

CLOUD_PROVIDERS = {
    "groq": {
        "name": "Groq",
        "desc": "Fastest cloud transcription (Whisper large-v3 on LPU)",
        "url": "https://api.groq.com/openai/v1/audio/transcriptions",
        "chat_url": "https://api.groq.com/openai/v1/chat/completions",
        "model": "whisper-large-v3",
        "llm_model": "llama-3.3-70b-versatile",
        "key_prefix": "gsk_",
        "key_url": "https://console.groq.com/keys",
    },
    "openai": {
        "name": "OpenAI",
        "desc": "OpenAI Whisper API — high accuracy, multilingual",
        "url": "https://api.openai.com/v1/audio/transcriptions",
        "chat_url": "https://api.openai.com/v1/chat/completions",
        "model": "whisper-1",
        "llm_model": "gpt-4o-mini",
        "key_prefix": "sk-",
        "key_url": "https://platform.openai.com/api-keys",
    },
    "deepgram": {
        "name": "Deepgram Nova",
        "desc": "Deepgram Nova-2 — fast, accurate, streaming-ready",
        "url": "https://api.deepgram.com/v1/listen",
        "chat_url": None,
        "model": "nova-2",
        "llm_model": None,
        "key_prefix": "",
        "key_url": "https://console.deepgram.com/",
    },
}


def audio_to_wav_bytes(audio_frames, sample_rate=SAMPLE_RATE, channels=CHANNELS):
    """Convert raw audio frames to WAV bytes."""
    audio_data = np.concatenate(audio_frames)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio_data.tobytes())
    buf.seek(0)
    return buf


# ── Transcription ────────────────────────────────────────────────────

def transcribe(audio_frames, api_key, provider="groq", language="auto"):
    """Transcribe audio using the specified cloud provider."""
    if not api_key:
        return "[ERROR] No API key configured"

    prov = CLOUD_PROVIDERS.get(provider)
    if not prov:
        return f"[ERROR] Unknown provider: {provider}"

    wav_buf = audio_to_wav_bytes(audio_frames)

    if provider == "deepgram":
        return _transcribe_deepgram(wav_buf, api_key, language, prov)
    else:
        return _transcribe_openai_compat(wav_buf, api_key, language, prov)


def _transcribe_openai_compat(wav_buf, api_key, language, prov):
    """Groq and OpenAI share the same OpenAI-compatible API format."""
    data = {"model": prov["model"], "response_format": "text"}
    if language and language != "auto":
        data["language"] = language

    resp = requests.post(
        prov["url"],
        headers={"Authorization": f"Bearer {api_key}"},
        files={"file": ("recording.wav", wav_buf, "audio/wav")},
        data=data,
        timeout=30,
    )

    if resp.status_code != 200:
        return f"[Transcription Error {resp.status_code}] {resp.text[:200]}"
    return resp.text.strip()


def _transcribe_deepgram(wav_buf, api_key, language, prov):
    """Deepgram uses a different REST API format."""
    params = {"model": prov["model"], "smart_format": "true"}
    if language and language != "auto":
        params["language"] = language

    resp = requests.post(
        prov["url"],
        headers={
            "Authorization": f"Token {api_key}",
            "Content-Type": "audio/wav",
        },
        params=params,
        data=wav_buf.read(),
        timeout=30,
    )

    if resp.status_code != 200:
        return f"[Transcription Error {resp.status_code}] {resp.text[:200]}"

    result = resp.json()
    try:
        return result["results"]["channels"][0]["alternatives"][0]["transcript"].strip()
    except (KeyError, IndexError):
        return "[ERROR] Unexpected Deepgram response format"


# ── LLM Cleanup ──────────────────────────────────────────────────────

def cleanup_text(raw_text, api_key, prompt=None, provider="groq"):
    """Use a cloud LLM to clean up transcribed text."""
    if not api_key or not raw_text or raw_text.startswith("["):
        return raw_text

    prov = CLOUD_PROVIDERS.get(provider)
    if not prov or not prov.get("chat_url"):
        # Deepgram has no chat API — fall back to groq/openai
        for fallback in ["groq", "openai"]:
            fb = CLOUD_PROVIDERS[fallback]
            if fb.get("chat_url"):
                prov = fb
                break
        if not prov or not prov.get("chat_url"):
            return raw_text

    from config import CLEANUP_PROMPT
    template = prompt if prompt else CLEANUP_PROMPT
    full_prompt = template.format(text=raw_text)

    resp = requests.post(
        prov["chat_url"],
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        json={
            "model": prov["llm_model"],
            "messages": [{"role": "user", "content": full_prompt}],
            "temperature": 0.3,
            "max_tokens": 2048,
        },
        timeout=30,
    )

    if resp.status_code != 200:
        return raw_text

    try:
        return resp.json()["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, TypeError):
        return raw_text
