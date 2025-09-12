#!/usr/bin/env python3
"""
MusicGen Model Installation Script Template
Installs and caches MusicGen models for audio generation.
"""
import os
import sys

def main():
    # Get parameters from command line
    if len(sys.argv) < 4:
        print("Usage: install_musicgen.py <model_name> <repo_id> <model_dir>")
        sys.exit(1)
    
    model_name = sys.argv[1]
    repo_id = sys.argv[2]
    model_dir = sys.argv[3]
    
    # Ensure transformers is available
    try:
        from transformers import MusicgenForConditionalGeneration, MusicgenProcessor
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
            
            cmd = [sys.executable, "-m", "pip", "install", "transformers"] + pip_flags
            subprocess.check_call(cmd)
            from transformers import MusicgenForConditionalGeneration, MusicgenProcessor
        except Exception as install_error:
            print(f"❌ Failed to install transformers: {install_error}")
            sys.exit(1)

    # Download and cache model
    try:
        print(f"Downloading MusicGen model: {repo_id}")
        model = MusicgenForConditionalGeneration.from_pretrained(repo_id)
        processor = MusicgenProcessor.from_pretrained(repo_id)
        
        # Save model info
        info_file = os.path.join(model_dir, "model_info.txt")
        with open(info_file, "w") as f:
            f.write(f"Model: {model_name}\n")
            f.write(f"Repository: {repo_id}\n")
            f.write("Type: MusicGen\n")
            f.write("Status: Downloaded\n")
        
        print("✅ MusicGen model cached successfully")
        return 0
        
    except Exception as e:
        print(f"❌ Error downloading model: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())