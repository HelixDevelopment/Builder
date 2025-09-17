#!/usr/bin/env python3
"""
Text-to-Speech Script Template
Converts text to natural speech using TTS models.
"""
import argparse
import os
import sys
from transformers import SpeechT5Processor, SpeechT5ForTextToSpeech, SpeechT5HifiGan
from datasets import load_dataset
import torch
import soundfile as sf

def text_to_speech(text, model_name="microsoft/speecht5_tts"):
    """Convert text to speech"""
    try:
        print(f"Loading TTS model: {model_name}")
        
        # Load model components
        processor = SpeechT5Processor.from_pretrained(model_name)
        model = SpeechT5ForTextToSpeech.from_pretrained(model_name)
        vocoder = SpeechT5HifiGan.from_pretrained("microsoft/speecht5_hifigan")
        
        # Load speaker embeddings - use a default speaker embedding
        print("Loading speaker embeddings...")
        try:
            # Try to load the dataset with trust_remote_code=True
            embeddings_dataset = load_dataset("Matthijs/cmu-arctic-xvectors", split="validation", trust_remote_code=True)
            speaker_embeddings = torch.tensor(embeddings_dataset[7306]["xvector"]).unsqueeze(0)
        except Exception as e:
            print(f"Warning: Could not load speaker embeddings dataset: {e}")
            print("Using default speaker embeddings...")
            # Create a default speaker embedding (512-dimensional vector)
            speaker_embeddings = torch.randn(1, 512)
        
        print(f"Generating speech for: '{text[:50]}...'")
        inputs = processor(text=text, return_tensors="pt")
        speech = model.generate_speech(inputs["input_ids"], speaker_embeddings, vocoder=vocoder)
        
        # Save audio file
        output_file = f"generated_speech_{hash(text) % 10000}.wav"
        sf.write(output_file, speech.numpy(), samplerate=16000)
        
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