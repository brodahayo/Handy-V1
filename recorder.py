"""Microphone recording handler."""

import pyaudio
import numpy as np
from config import SAMPLE_RATE, CHANNELS, CHUNK_SIZE


class Recorder:
    def __init__(self):
        self.audio = pyaudio.PyAudio()
        self.stream = None
        self.frames = []
        self.is_recording = False
        self.current_rms = 0.0  # Real-time audio level (0.0 - 1.0)

    def start(self):
        """Start recording from the microphone."""
        self.frames = []
        self.current_rms = 0.0
        self.is_recording = True
        self.stream = self.audio.open(
            format=pyaudio.paInt16,
            channels=CHANNELS,
            rate=SAMPLE_RATE,
            input=True,
            frames_per_buffer=CHUNK_SIZE,
            stream_callback=self._callback,
        )
        self.stream.start_stream()

    def _callback(self, in_data, frame_count, time_info, status):
        if self.is_recording:
            audio_array = np.frombuffer(in_data, dtype=np.int16)
            self.frames.append(audio_array)
            # Calculate RMS for real-time level meter
            rms = np.sqrt(np.mean(audio_array.astype(np.float32) ** 2)) / 32768.0
            self.current_rms = min(1.0, rms * 25.0)  # Amplify for visual range
        return (in_data, pyaudio.paContinue)

    def stop(self):
        """Stop recording and return captured audio frames."""
        self.is_recording = False
        if self.stream:
            self.stream.stop_stream()
            self.stream.close()
            self.stream = None
        return self.frames

    def cleanup(self):
        """Release audio resources."""
        if self.stream:
            self.stream.stop_stream()
            self.stream.close()
        self.audio.terminate()
