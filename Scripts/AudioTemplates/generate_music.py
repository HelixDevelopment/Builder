#!/usr/bin/env python3
"""
Music Generation Script Template
Generates music from text descriptions using MusicGen models.
"""
import argparse
import os
import sys
from transformers import MusicgenForConditionalGeneration, MusicgenProcessor
import scipy.io.wavfile

def generate_music(prompt, model_name="facebook/musicgen-small", duration=10):
    """Generate music from text prompt"""
    try:
        print(f"Loading MusicGen model: {model_name}")
        model = MusicgenForConditionalGeneration.from_pretrained(model_name)
        processor = MusicgenProcessor.from_pretrained(model_name)
        
        print(f"Generating audio for: '{prompt}'")
        inputs = processor(
            text=[prompt],
            padding=True,
            return_tensors="pt"
        )
        
        audio_values = model.generate(**inputs, max_new_tokens=duration*50)
        
        # Save audio file
        output_file = f"generated_music_{hash(prompt) % 10000}.wav"
        sampling_rate = model.config.audio_encoder.sampling_rate
        scipy.io.wavfile.write(output_file, rate=sampling_rate, data=audio_values[0, 0].cpu().numpy())
        
        print(f"✅ Audio saved to: {output_file}")
        return output_file
        
    except Exception as e:
        print(f"❌ Error generating music: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Generate music with MusicGen")
    parser.add_argument("prompt", help="Text description for music generation")
    parser.add_argument("--model", default="facebook/musicgen-small", help="Model to use")
    parser.add_argument("--duration", type=int, default=10, help="Duration in seconds")
    
    args = parser.parse_args()
    result = generate_music(args.prompt, args.model, args.duration)
    return 0 if result else 1

if __name__ == "__main__":
    sys.exit(main())