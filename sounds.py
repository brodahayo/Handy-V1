"""Sound effects for Handy — short, premium audio cues.

Five sound packs:
  woody   — warm marimba-like tones
  crystal — bright glass chimes
  bubble  — soft liquid pops
  chirp   — playful melodic chirps
  synth   — lush polished synth tones
"""

import os
import wave
import struct
import math
import random
from AppKit import NSSound

SOUNDS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")

# Available sound packs
SOUND_PACKS = {
    "woody":   "Woody",
    "crystal": "Crystal",
    "bubble":  "Bubble",
    "chirp":   "Chirp",
    "synth":   "Synth",
}

# Cache loaded sounds
_cache = {}


def _write_wav(path, samples, sample_rate=44100):
    """Write raw samples to a WAV file."""
    with wave.open(path, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        for s in samples:
            wf.writeframes(struct.pack("<h", int(max(-32767, min(32767, s)))))


def _noise():
    """White noise sample."""
    return random.uniform(-1, 1)


def _softclip(x):
    """Gentle saturation for warmth."""
    return math.tanh(x * 1.2)


# ── Generators ────────────────────────────────────────────────────────

def _gen_woody_start(path):
    """Typewriter key down — crisp mechanical clack with spring."""
    sr = 44100
    dur = 0.045
    n = int(sr * dur)
    random.seed(42)
    samples = []
    for i in range(n):
        t = i / sr
        p = i / n
        # Sharp impact — instant attack, very fast decay
        impact = math.exp(-t * 800)
        # Mechanical click — band-passed noise burst
        click = _noise() * impact * 0.9
        # Metal spring ping — high freq, dies fast
        spring = math.sin(2 * math.pi * 3200 * t) * math.exp(-t * 500) * 0.35
        # Plastic thock body — low resonance of key bottoming out
        thock = math.sin(2 * math.pi * 420 * t) * math.exp(-t * 120) * 0.6
        # Slight case resonance
        case_res = math.sin(2 * math.pi * 180 * t) * math.exp(-t * 80) * 0.3
        val = click + spring + thock + case_res
        samples.append(_softclip(val) * 14000)
    _write_wav(path, samples, sr)


def _gen_woody_stop(path):
    """Typewriter key up — softer click with spring release."""
    sr = 44100
    dur = 0.04
    n = int(sr * dur)
    random.seed(43)
    samples = []
    for i in range(n):
        t = i / sr
        # Softer, lighter — the key releasing back up
        impact = math.exp(-t * 900)
        # Lighter click
        click = _noise() * impact * 0.55
        # Higher spring — key bouncing back
        spring = math.sin(2 * math.pi * 4000 * t) * math.exp(-t * 600) * 0.3
        # Lighter thock
        thock = math.sin(2 * math.pi * 500 * t) * math.exp(-t * 150) * 0.35
        val = click + spring + thock
        samples.append(_softclip(val) * 11000)
    _write_wav(path, samples, sr)


def _gen_crystal_start(path):
    """Glass chime — bright, shimmery, with reverb tail."""
    sr = 44100
    dur = 0.3
    n = int(sr * dur)
    random.seed(44)
    samples = []
    for i in range(n):
        t = i / sr
        p = i / n
        attack = 1 - math.exp(-t * 500)
        decay = math.exp(-t * 6)
        env = attack * decay

        # Bell-like inharmonic partials
        f0 = 1568  # G6
        val = math.sin(2 * math.pi * f0 * t) * 1.0
        val += math.sin(2 * math.pi * f0 * 2.76 * t) * 0.4 * math.exp(-t * 8)   # inharmonic
        val += math.sin(2 * math.pi * f0 * 5.4 * t) * 0.15 * math.exp(-t * 12)   # shimmer
        val += math.sin(2 * math.pi * f0 * 0.5 * t) * 0.2 * math.exp(-t * 10)    # body

        # High sparkle
        val += math.sin(2 * math.pi * 4186 * t) * 0.08 * math.exp(-t * 20)
        # Noise transient
        val += _noise() * math.exp(-t * 400) * 0.25

        samples.append(_softclip(val * env) * 8000)
    _write_wav(path, samples, sr)


def _gen_crystal_stop(path):
    """Glass chime — descending with gentle ring-out."""
    sr = 44100
    dur = 0.35
    n = int(sr * dur)
    random.seed(45)
    samples = []
    for i in range(n):
        t = i / sr
        attack = 1 - math.exp(-t * 400)
        decay = math.exp(-t * 5)
        env = attack * decay

        # Descending bell
        f0 = 1318.5  # E6
        val = math.sin(2 * math.pi * f0 * t) * 1.0
        val += math.sin(2 * math.pi * f0 * 2.76 * t) * 0.35 * math.exp(-t * 8)
        val += math.sin(2 * math.pi * f0 * 5.4 * t) * 0.12 * math.exp(-t * 14)

        # Second chime lower, offset 100ms
        t2 = t - 0.1
        if t2 > 0:
            f2 = 987.77  # B5
            a2 = 1 - math.exp(-t2 * 400)
            d2 = math.exp(-t2 * 5)
            e2 = a2 * d2 * 0.7
            val += math.sin(2 * math.pi * f2 * t2) * e2
            val += math.sin(2 * math.pi * f2 * 2.76 * t2) * 0.3 * math.exp(-t2 * 9) * e2

        val += _noise() * math.exp(-t * 500) * 0.2
        samples.append(_softclip(val * env) * 7500)
    _write_wav(path, samples, sr)


def _gen_bubble_start(path):
    """Liquid pop — round, warm, satisfying."""
    sr = 44100
    dur = 0.14
    n = int(sr * dur)
    random.seed(46)
    samples = []
    for i in range(n):
        t = i / sr
        # Rapid pitch rise like water drop
        freq = 300 + 900 * (1 - math.exp(-t * 60))
        attack = 1 - math.exp(-t * 600)
        decay = math.exp(-t * 18)
        env = attack * decay * math.sin(min(t / 0.14, 1) * math.pi)  # dome

        val = math.sin(2 * math.pi * freq * t)
        # Sub thump for body
        val += math.sin(2 * math.pi * 150 * t) * 0.5 * math.exp(-t * 30)
        # Soft overtone
        val += math.sin(2 * math.pi * freq * 2 * t) * 0.2 * math.exp(-t * 25)
        # Filtered noise for texture
        val += _noise() * math.exp(-t * 80) * 0.15

        samples.append(_softclip(val * env) * 13000)
    _write_wav(path, samples, sr)


def _gen_bubble_stop(path):
    """Double liquid pop — descending, round."""
    sr = 44100
    dur = 0.2
    n = int(sr * dur)
    random.seed(47)
    samples = []
    for i in range(n):
        t = i / sr
        val = 0.0

        # Pop 1 — higher
        freq1 = 600 + 400 * (1 - math.exp(-t * 50))
        e1 = (1 - math.exp(-t * 500)) * math.exp(-t * 20)
        dome1 = math.sin(min(t / 0.08, 1) * math.pi)
        val += math.sin(2 * math.pi * freq1 * t) * e1 * dome1
        val += math.sin(2 * math.pi * 120 * t) * 0.4 * math.exp(-t * 35)

        # Pop 2 — lower, offset 70ms
        t2 = t - 0.07
        if t2 > 0:
            freq2 = 400 + 300 * (1 - math.exp(-t2 * 50))
            e2 = (1 - math.exp(-t2 * 500)) * math.exp(-t2 * 18) * 0.8
            dome2 = math.sin(min(t2 / 0.08, 1) * math.pi)
            val += math.sin(2 * math.pi * freq2 * t2) * e2 * dome2

        val += _noise() * math.exp(-t * 100) * 0.1
        samples.append(_softclip(val) * 12000)
    _write_wav(path, samples, sr)


def _gen_chirp_start(path):
    """Melodic two-note ascending chirp — playful & bright."""
    sr = 44100
    dur = 0.16
    n = int(sr * dur)
    random.seed(48)
    samples = []
    for i in range(n):
        t = i / sr
        val = 0.0

        # Note 1 — quick ascending
        f1 = 1047  # C6
        e1 = (1 - math.exp(-t * 300)) * math.exp(-t * 25)
        val += math.sin(2 * math.pi * f1 * t) * e1
        val += math.sin(2 * math.pi * f1 * 2 * t) * 0.3 * e1 * math.exp(-t * 30)

        # Note 2 — higher, offset 65ms
        t2 = t - 0.065
        if t2 > 0:
            f2 = 1319  # E6
            e2 = (1 - math.exp(-t2 * 300)) * math.exp(-t2 * 20) * 0.9
            val += math.sin(2 * math.pi * f2 * t2) * e2
            val += math.sin(2 * math.pi * f2 * 2 * t2) * 0.25 * e2 * math.exp(-t2 * 28)

        val += _noise() * math.exp(-t * 200) * 0.12
        samples.append(_softclip(val) * 9000)
    _write_wav(path, samples, sr)


def _gen_chirp_stop(path):
    """Melodic two-note descending chirp — gentle resolution."""
    sr = 44100
    dur = 0.18
    n = int(sr * dur)
    random.seed(49)
    samples = []
    for i in range(n):
        t = i / sr
        val = 0.0

        # Note 1 — high
        f1 = 1319  # E6
        e1 = (1 - math.exp(-t * 300)) * math.exp(-t * 22)
        val += math.sin(2 * math.pi * f1 * t) * e1
        val += math.sin(2 * math.pi * f1 * 2 * t) * 0.25 * e1 * math.exp(-t * 28)

        # Note 2 — lower, offset 75ms
        t2 = t - 0.075
        if t2 > 0:
            f2 = 987.77  # B5
            e2 = (1 - math.exp(-t2 * 300)) * math.exp(-t2 * 18) * 0.85
            val += math.sin(2 * math.pi * f2 * t2) * e2
            val += math.sin(2 * math.pi * f2 * 2 * t2) * 0.2 * e2 * math.exp(-t2 * 25)

        val += _noise() * math.exp(-t * 200) * 0.1
        samples.append(_softclip(val) * 8500)
    _write_wav(path, samples, sr)


def _gen_synth_start(path):
    """Lush synth chord — polished, modern, warm rise."""
    sr = 44100
    dur = 0.28
    n = int(sr * dur)
    random.seed(50)
    samples = []
    for i in range(n):
        t = i / sr
        p = i / n
        # Soft attack, long sustain tail
        attack = 1 - math.exp(-t * 80)
        decay = math.exp(-t * 4.5)
        env = attack * decay

        # Major 7th chord — lush and modern
        root = 523.25  # C5
        val = math.sin(2 * math.pi * root * t)                          # C5
        val += math.sin(2 * math.pi * root * 1.25 * t) * 0.5           # E5
        val += math.sin(2 * math.pi * root * 1.498 * t) * 0.4          # G5
        val += math.sin(2 * math.pi * root * 1.888 * t) * 0.25         # B5 (maj7)
        # Sub octave for warmth
        val += math.sin(2 * math.pi * root * 0.5 * t) * 0.35 * math.exp(-t * 6)
        # Detuned unison for width
        val += math.sin(2 * math.pi * (root * 1.003) * t) * 0.3
        val += math.sin(2 * math.pi * (root * 0.997) * t) * 0.3
        # Gentle high shimmer
        val += math.sin(2 * math.pi * root * 4 * t) * 0.06 * math.exp(-t * 10)

        samples.append(_softclip(val * env * 0.45) * 12000)
    _write_wav(path, samples, sr)


def _gen_synth_stop(path):
    """Lush synth chord — resolving, warm descent."""
    sr = 44100
    dur = 0.32
    n = int(sr * dur)
    random.seed(51)
    samples = []
    for i in range(n):
        t = i / sr
        attack = 1 - math.exp(-t * 80)
        decay = math.exp(-t * 4)
        env = attack * decay

        # Minor 7th for gentle resolution
        root = 440  # A4
        val = math.sin(2 * math.pi * root * t)                          # A4
        val += math.sin(2 * math.pi * root * 1.2 * t) * 0.5            # C5
        val += math.sin(2 * math.pi * root * 1.498 * t) * 0.4          # E5
        val += math.sin(2 * math.pi * root * 1.782 * t) * 0.2          # G5 (min7)
        # Sub warmth
        val += math.sin(2 * math.pi * root * 0.5 * t) * 0.3 * math.exp(-t * 5)
        # Detuned width
        val += math.sin(2 * math.pi * (root * 1.004) * t) * 0.25
        val += math.sin(2 * math.pi * (root * 0.996) * t) * 0.25
        # Tail shimmer
        val += math.sin(2 * math.pi * root * 3 * t) * 0.05 * math.exp(-t * 8)

        samples.append(_softclip(val * env * 0.42) * 11000)
    _write_wav(path, samples, sr)


# ── Generator registry ────────────────────────────────────────────────

_GENERATORS = {
    "woody":   (_gen_woody_start,   _gen_woody_stop),
    "crystal": (_gen_crystal_start, _gen_crystal_stop),
    "bubble":  (_gen_bubble_start,  _gen_bubble_stop),
    "chirp":   (_gen_chirp_start,   _gen_chirp_stop),
    "synth":   (_gen_synth_start,   _gen_synth_stop),
}


def _ensure_pack(pack):
    """Generate sound files for a pack if they don't exist."""
    os.makedirs(SOUNDS_DIR, exist_ok=True)
    start_path = os.path.join(SOUNDS_DIR, f"{pack}_start.wav")
    stop_path = os.path.join(SOUNDS_DIR, f"{pack}_stop.wav")
    gen_start, gen_stop = _GENERATORS.get(pack, _GENERATORS["woody"])
    if not os.path.exists(start_path):
        gen_start(start_path)
    if not os.path.exists(stop_path):
        gen_stop(stop_path)


def _get_pack():
    """Get the current sound pack from settings."""
    try:
        import settings as settings_mgr
        return settings_mgr.get("sound_pack") or "woody"
    except Exception:
        return "woody"


def _load_sound(name):
    """Load and cache an NSSound."""
    if name in _cache:
        return _cache[name]

    pack = _get_pack()
    _ensure_pack(pack)
    path = os.path.join(SOUNDS_DIR, f"{pack}_{name}.wav")
    if not os.path.exists(path):
        # Fallback to woody
        _ensure_pack("woody")
        path = os.path.join(SOUNDS_DIR, f"woody_{name}.wav")

    sound = NSSound.alloc().initWithContentsOfFile_byReference_(path, True)
    if sound:
        sound.setVolume_(0.25)
        _cache[name] = sound
    return sound


def _is_enabled():
    """Check if sounds are enabled in settings."""
    try:
        import settings as settings_mgr
        return settings_mgr.get("sound_enabled") is not False
    except Exception:
        return True


def invalidate_cache():
    """Clear the sound cache (call when user changes sound pack)."""
    _cache.clear()


def play_start():
    """Play the recording-start sound (non-blocking)."""
    if not _is_enabled():
        return
    s = _load_sound("start")
    if s:
        s.stop()
        s.play()


def play_stop():
    """Play the recording-stop sound (non-blocking)."""
    if not _is_enabled():
        return
    s = _load_sound("stop")
    if s:
        s.stop()
        s.play()


def preview(pack, which="start"):
    """Preview a specific sound pack. Returns True if played."""
    _ensure_pack(pack)
    path = os.path.join(SOUNDS_DIR, f"{pack}_{which}.wav")
    sound = NSSound.alloc().initWithContentsOfFile_byReference_(path, True)
    if sound:
        sound.setVolume_(0.3)
        sound.stop()
        sound.play()
        return True
    return False
