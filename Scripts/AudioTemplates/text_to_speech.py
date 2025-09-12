#!/usr/bin/env python3
"""
Text-to-Speech Script Template
Converts text to natural speech using TTS models.
"""
import argparse
import os
import sys
from transformers import pipeline
import soundfile as sf

def text_to_speech(text, model_name="microsoft/speecht5_tts"):
    """Convert text to speech"""
    try:
        print(f"Loading TTS model: {model_name}")
        synthesiser = pipeline("text-to-speech", model=model_name)
        
        print(f"Generating speech for: '{text[:50]}...'")
        speech = synthesiser(text)
        
        # Save audio file
        output_file = f"generated_speech_{hash(text) % 10000}.wav"
        sf.write(output_file, speech["audio"], speech["sampling_rate"])
        
        print(f"✅ Speech saved to: {output_file}")
        return output_file
        
    except Exception as e:
        print(f"❌ Error generating speech: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Generate speech with TTS")
    parser.add_argument("text", help="Text to convert to speech")
    parser.add_argument("--model", default="microsoft/speecht5_tts", help="TTS model to use")
    
    args = parser.parse_args()
    result = text_to_speech(args.text, args.model)
    return 0 if result else 1

if __name__ == "__main__":
    sys.exit(main())