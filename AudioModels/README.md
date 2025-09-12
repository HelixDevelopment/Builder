# AudioModels Directory

This directory contains audio generation models and their associated runtime environments. It is automatically created and managed by the audio installation system.

## ⚠️ Important Notes

- **Do NOT commit this directory to version control** - it contains large model files and virtual environments
- **Total size can be 5-50GB** depending on models installed
- **Models are cached locally** for faster subsequent use
- **Safe to delete** - will be recreated on next audio model installation

## Directory Structure

```
AudioModels/
├── venv/                     # Python virtual environment
├── musicgen/                 # MusicGen models
│   ├── musicgen-small/
│   ├── musicgen-medium/
│   └── musicgen-large/
├── tts/                      # Text-to-Speech models
│   ├── speech-t5/
│   └── xtts-v2/
├── bark/                     # Bark audio models
│   ├── bark-small/
│   ├── bark-medium/
│   └── bark-large/
└── scripts/                  # Generated usage scripts
    ├── generate_music.py
    └── text_to_speech.py
```

## Usage

After audio models are installed, use the generated scripts:

```bash
# Generate music from text
python3 AudioModels/scripts/generate_music.py "upbeat electronic music"

# Convert text to speech
python3 AudioModels/scripts/text_to_speech.py "Hello world"
```

## Reinstallation

To reinstall audio models:
```bash
rm -rf AudioModels/  # Remove everything
./Scripts/install.sh Generative/Audio  # Reinstall
```

## Storage Management

Models consume significant disk space:
- **Small models (7B)**: ~2-5GB total
- **Medium models (13B)**: ~5-15GB total  
- **Large models (34B)**: ~15-30GB total
- **Largest models (70B)**: ~30-50GB total

To free space, delete unused model categories:
```bash
rm -rf AudioModels/bark/     # Remove Bark models
rm -rf AudioModels/musicgen/ # Remove MusicGen models
```