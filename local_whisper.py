"""
Offline transcription using faster-whisper with a model catalog for in-app downloads.
"""

import os
import numpy as np

_model = None
_model_size_loaded = None

# ── Model Catalog ────────────────────────────────────────────────────

LOCAL_MODELS = {
    "tiny": {
        "name": "Tiny",
        "id": "tiny",
        "size_mb": 74,
        "language": "Multilingual",
        "desc": "Quick transcription — fastest, least accurate",
        "hf_repo": "Systran/faster-whisper-tiny",
    },
    "tiny.en": {
        "name": "Tiny (English)",
        "id": "tiny.en",
        "size_mb": 74,
        "language": "English-only",
        "desc": "Quick English transcription",
        "hf_repo": "Systran/faster-whisper-tiny.en",
    },
    "base": {
        "name": "Base",
        "id": "base",
        "size_mb": 141,
        "language": "Multilingual",
        "desc": "General use (recommended)",
        "hf_repo": "Systran/faster-whisper-base",
    },
    "base.en": {
        "name": "Base (English)",
        "id": "base.en",
        "size_mb": 141,
        "language": "English-only",
        "desc": "General English use (recommended)",
        "hf_repo": "Systran/faster-whisper-base.en",
    },
    "small": {
        "name": "Small",
        "id": "small",
        "size_mb": 465,
        "language": "Multilingual",
        "desc": "Professional transcription — good balance",
        "hf_repo": "Systran/faster-whisper-small",
    },
    "small.en": {
        "name": "Small (English)",
        "id": "small.en",
        "size_mb": 465,
        "language": "English-only",
        "desc": "Professional English transcription",
        "hf_repo": "Systran/faster-whisper-small.en",
    },
    "medium": {
        "name": "Medium",
        "id": "medium",
        "size_mb": 1500,
        "language": "Multilingual",
        "desc": "High accuracy transcription",
        "hf_repo": "Systran/faster-whisper-medium",
    },
    "medium.en": {
        "name": "Medium (English)",
        "id": "medium.en",
        "size_mb": 1500,
        "language": "English-only",
        "desc": "High accuracy English transcription",
        "hf_repo": "Systran/faster-whisper-medium.en",
    },
    "large-v3": {
        "name": "Large V3",
        "id": "large-v3",
        "size_mb": 3000,
        "language": "Multilingual",
        "desc": "Highest accuracy — best quality, slowest",
        "hf_repo": "Systran/faster-whisper-large-v3",
    },
}


def is_available():
    """Returns True if faster-whisper is installed."""
    try:
        import faster_whisper  # noqa: F401
        return True
    except ImportError:
        return False


def _get_cache_dir():
    """Return the Hugging Face hub cache directory where models are stored."""
    return os.path.join(os.path.expanduser("~"), ".cache", "huggingface", "hub")


def is_model_downloaded(model_id):
    """Check if a specific model has been downloaded to the HF cache."""
    if not is_available():
        return False
    info = LOCAL_MODELS.get(model_id)
    if not info:
        return False
    repo = info["hf_repo"]
    # HF hub stores repos as models--org--name
    dir_name = "models--" + repo.replace("/", "--")
    model_dir = os.path.join(_get_cache_dir(), dir_name)
    return os.path.isdir(model_dir)


def get_model_catalog():
    """Return the full model catalog with download status."""
    catalog = []
    for model_id, info in LOCAL_MODELS.items():
        entry = dict(info)
        entry["downloaded"] = is_model_downloaded(model_id)
        catalog.append(entry)
    return catalog


def _get_model(model_size="base"):
    """Return a cached WhisperModel singleton, loading it on first call."""
    global _model, _model_size_loaded

    if _model is not None and _model_size_loaded == model_size:
        return _model

    from faster_whisper import WhisperModel

    _model = WhisperModel(model_size, device="cpu", compute_type="int8")
    _model_size_loaded = model_size
    return _model


def transcribe_local(audio_frames, language="auto", model_size="base"):
    """Transcribe audio frames using faster-whisper."""
    model = _get_model(model_size)
    audio = np.concatenate(audio_frames).astype(np.float32) / 32768.0

    kwargs = {}
    if language != "auto":
        kwargs["language"] = language

    segments, _ = model.transcribe(audio, **kwargs)
    return " ".join(segment.text.strip() for segment in segments)


def download_model(model_size="base", progress_callback=None):
    """Download a model. Calls progress_callback(percent) if provided."""
    from faster_whisper import WhisperModel
    # Instantiating the model triggers HF hub download
    WhisperModel(model_size, device="cpu", compute_type="int8")


def delete_model(model_id):
    """Delete a downloaded model from the HF cache."""
    import shutil
    info = LOCAL_MODELS.get(model_id)
    if not info:
        return False
    repo = info["hf_repo"]
    dir_name = "models--" + repo.replace("/", "--")
    model_dir = os.path.join(_get_cache_dir(), dir_name)
    if os.path.isdir(model_dir):
        shutil.rmtree(model_dir)
        return True
    return False
