#!/bin/bash
# VoiceType Setup Script

echo "=== VoiceType Setup ==="

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install portaudio (needed for PyAudio)
echo "Installing portaudio..."
brew install portaudio

# Install Python dependencies
echo "Installing Python packages..."
pip3 install pyaudio numpy rumps pyperclip requests pynput

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Get a free Groq API key at: https://console.groq.com/keys"
echo "2. Paste it in config.py (GROQ_API_KEY = \"your-key-here\")"
echo "3. Run: python3 app.py"
echo "4. Use Option+V to start/stop recording"
echo ""
echo "Note: You'll need to grant these permissions in System Settings:"
echo "  - Microphone access (for recording)"
echo "  - Accessibility access (for pasting into fields)"
