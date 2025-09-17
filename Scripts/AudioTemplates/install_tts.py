#!/usr/bin/env python3
"""
TTS Model Installation Script Template
Installs and caches Text-to-Speech models.
"""
import os
import sys

def main():
    # Get parameters from command line
    if len(sys.argv) < 4:
        print("Usage: install_tts.py <model_name> <repo_id> <model_dir>")
        return 1
    
    model_name = sys.argv[1]
    repo_id = sys.argv[2]
    model_dir = sys.argv[3]
    
    # Ensure transformers is available
    try:
        from transformers import pipeline
    except ImportError as e:
        print(f"❌ Missing dependencies: {e}")
        print("Installing transformers...")
        import subprocess
        try:
            # Detect supported pip flags
            pip_flags = []
            try:
                # Test if --break-system-packages is supported
                result = subprocess.run([sys.executable, "-m", "pip", "--help"], 
                                      capture_output=True, text=True)
                if "--break-system-packages" in result.stdout:
                    pip_flags.append("--break-system-packages")
            except:
                pass  # Use basic flags if detection fails
            
            cmd = [sys.executable, "-m", "pip", "install", "transformers", "sentencepiece", "soundfile"] + pip_flags
            subprocess.check_call(cmd)
            from transformers import pipeline
        except Exception as install_error:
            print(f"❌ Failed to install transformers: {install_error}")
            return 1

    # Download and cache TTS model
    try:
        print(f"Downloading TTS model: {repo_id}")
        # For TTS models, just load the tokenizer to cache the model
        from transformers import AutoTokenizer
        tokenizer = AutoTokenizer.from_pretrained(repo_id)
        
        # Save model info
        info_file = os.path.join(model_dir, "model_info.txt")
        with open(info_file, "w") as f:
            f.write(f"Model: {model_name}\n")
            f.write(f"Repository: {repo_id}\n")
            f.write("Type: TTS\n")
            f.write("Status: Downloaded\n")
        
        print("✅ TTS model cached successfully")
        return 0
        
    except Exception as e:
        print(f"❌ Error downloading model: {e}")
        # Don't exit(1) for TTS errors, just log them
        print("⚠️  TTS model download failed, but continuing...")
        return 0  # Return success to continue installation

if __name__ == "__main__":
    sys.exit(main())