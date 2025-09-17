#!/bin/bash

# Audio Models Installation Script
# This script handles installation of audio generation models using specialized frameworks

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "🎵 Audio Models Installation System"
echo "=================================="

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required for audio model installation"
    exit 1
fi

# Check and install system dependencies
check_system_dependencies() {
    echo "🔧 Checking system dependencies..."
    
    # Check if python3-venv is available
    if ! python3 -m venv --help &> /dev/null; then
        echo "📦 Installing python3-venv package..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y python3-venv python3-full python3-dev build-essential cmake pkg-config libsndfile1
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y python3-venv python3-devel gcc-c++ cmake pkgconfig libsndfile-devel
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3-venv python3-devel gcc-c++ cmake pkgconfig libsndfile-devel
        else
            echo "❌ Please install python3-venv package for your distribution"
            exit 1
        fi
    fi
    
    # Check if pipx is available for fallback
    if ! command -v pipx &> /dev/null; then
        echo "📦 Installing pipx as fallback..."
        if command -v apt &> /dev/null; then
            sudo apt install -y pipx
            pipx ensurepath
        fi
    fi
}

check_system_dependencies

# Force cleanup of broken venv attempts
if [ -d "$HERE/../AudioModels/venv" ] && [ ! -f "$HERE/../AudioModels/venv/bin/python3" ]; then
    echo "🧹 Cleaning up broken virtual environment..."
    rm -rf "$HERE/../AudioModels/venv"
fi

# Function to install audio generation dependencies
install_audio_dependencies() {
    echo "📦 Installing audio generation dependencies..."
    
    # Create virtual environment for audio models
    local venv_path="$HERE/../AudioModels/venv"
    
    if [ ! -d "$venv_path" ] || [ ! -f "$venv_path/bin/python3" ]; then
        echo "Creating virtual environment for audio models..."
        mkdir -p "$HERE/../AudioModels"
        
        # Remove any incomplete venv
        rm -rf "$venv_path"
        
        # Create virtual environment with better error handling
        echo "🔧 Creating virtual environment at: $venv_path"
        
        # First try with --system-site-packages
        if python3 -m venv --system-site-packages "$venv_path" 2>&1; then
            echo "✅ Virtual environment created with system packages access"
        else
            echo "⚠️  System-site-packages failed, trying isolated venv..."
            rm -rf "$venv_path"  # Clean up partial creation
            
            if python3 -m venv "$venv_path" 2>&1; then
                echo "✅ Virtual environment created (isolated)"
            else
                echo "❌ Virtual environment creation failed completely"
                echo "📍 Python version: $(python3 --version)"
                echo "📍 Venv module test: $(python3 -m venv --help >/dev/null 2>&1 && echo 'AVAILABLE' || echo 'NOT AVAILABLE')"
            fi
        fi
        
        # Verify the venv was created properly (if it was supposed to be created)
        if [ -d "$venv_path" ] && [ ! -f "$venv_path/bin/python3" ]; then
            echo "⚠️  Virtual environment incomplete - removing and using system Python"
            rm -rf "$venv_path"
        fi
    fi
    
    # Verify and activate virtual environment
    echo "🔍 Checking virtual environment status..."
    if [ -f "$venv_path/bin/activate" ] && [ -f "$venv_path/bin/python3" ] && [ -f "$venv_path/bin/pip" ]; then
        source "$venv_path/bin/activate"
        echo "✅ Virtual environment activated successfully"
        echo "📍 Using Python: $(which python)"
        echo "📍 Using pip: $(which pip)"
    else
        echo "⚠️  Virtual environment not available or incomplete"
        echo "📍 Looking for: $venv_path/bin/activate"
        echo "📍 Activate exists: $([ -f "$venv_path/bin/activate" ] && echo 'YES' || echo 'NO')"
        echo "📍 Python exists: $([ -f "$venv_path/bin/python3" ] && echo 'YES' || echo 'NO')"  
        echo "📍 Pip exists: $([ -f "$venv_path/bin/pip" ] && echo 'YES' || echo 'NO')"
        echo "⚠️  Will use system Python with compatible flags"
    fi
    
    # Install basic audio dependencies
    echo "📦 Installing Python packages..."
    
    # Use the virtual environment's pip
    local pip_cmd="$venv_path/bin/pip"
    local pip_flags=""
    
    if [ ! -f "$pip_cmd" ]; then
        echo "⚠️  Virtual environment pip not found, using system pip"
        pip_cmd="pip3"
        
        # Check if this is an externally-managed environment
        if python3 -c "import sys; print(sys.prefix)" 2>/dev/null | grep -q "/usr" && [ ! -w "$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "/usr/lib/python3/dist-packages")" ]; then
            echo "❌ Detected externally-managed environment - virtual environment is required"
            echo "🔧 Forcing virtual environment creation..."
            
            # Force create a working virtual environment
            local force_venv_path="$HERE/../AudioModels/venv"
            rm -rf "$force_venv_path"
            
            if python3 -m venv "$force_venv_path"; then
                echo "✅ Emergency virtual environment created"
                pip_cmd="$force_venv_path/bin/pip"
                pip_flags=""
                
                # Update PYTHON_CMD for model installation
                export PYTHON_CMD="$force_venv_path/bin/python"
            else
                echo "❌ Cannot create virtual environment - installation will fail"
                return 1
            fi
        else
            # Test which flags this pip version supports
            if $pip_cmd --help | grep -q -- "--break-system-packages" 2>/dev/null; then
                pip_flags="--break-system-packages"
                echo "📦 Using --break-system-packages flag for system pip"
            else
                pip_flags=""
                echo "📦 Using basic pip flags (no system packages support)"
            fi
        fi
    fi
    
    $pip_cmd $pip_flags install --upgrade pip
    $pip_cmd $pip_flags install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    $pip_cmd $pip_flags install transformers
    $pip_cmd $pip_flags install sentencepiece  # Fix for TTS models
    $pip_cmd $pip_flags install datasets  # For speaker embeddings
    $pip_cmd $pip_flags install scipy
    $pip_cmd $pip_flags install librosa
    $pip_cmd $pip_flags install soundfile
    $pip_cmd $pip_flags install accelerate
    
    echo "✅ Audio dependencies installed"
}

# Function to install specific audio models
install_audio_models() {
    local MODELS="$1"
    
    if [ ! -f "$MODELS" ]; then
        echo "❌ Models file not found: $MODELS"
        return 1
    fi
    
    # Setup Python environment for model installation
    local venv_path="$HERE/../AudioModels/venv"
    local python_cmd="python3"
    
    if [ -f "$venv_path/bin/activate" ]; then
        echo "🐍 Activating virtual environment for model installation..."
        source "$venv_path/bin/activate"
        python_cmd="$venv_path/bin/python3"
    else
        echo "⚠️  Using system Python for model installation"
        python_cmd="python3"
    fi
    
    # Export for use in model installation scripts
    export PYTHON_CMD="$python_cmd"
    
    echo "======================================"
    echo "Models for installation:"
    cat "$MODELS" && echo ""
    
    local total_models=0
    local success_count=0
    local fail_count=0
    
    while IFS= read -r model_entry || [[ -n "$model_entry" ]]; do
        
        if [[ -z "$model_entry" || "$model_entry" =~ ^# ]]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Skipping: $model_entry"
            continue
        fi
        
        ((total_models++))
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing audio model: $model_entry"
        
        # Parse model entry (format: model_name:type:repo_id)
        IFS=':' read -ra MODEL_PARTS <<< "$model_entry"
        model_name="${MODEL_PARTS[0]}"
        model_type="${MODEL_PARTS[1]:-musicgen}"
        model_repo="${MODEL_PARTS[2]:-facebook/musicgen-small}"
        
        case "$model_type" in
            "musicgen")
                install_musicgen_model "$model_name" "$model_repo"
                ;;
            "tts")
                install_tts_model "$model_name" "$model_repo"
                ;;
            "bark")
                install_bark_model "$model_name" "$model_repo"
                ;;
            *)
                echo "⚠️  Unknown model type: $model_type"
                ((fail_count++))
                continue
                ;;
        esac
        
        if [ $? -eq 0 ]; then
            echo "✅ Success: $model_entry"
            ((success_count++))
        else
            echo "❌ FAILED: $model_entry"
            ((fail_count++))
        fi
        
        echo "--------------------------------------"
        
    done < "$MODELS"
    
    echo "=============================================="
    echo "AUDIO INSTALLATION SUMMARY:"
    echo "Total models processed: $total_models"
    echo "Successfully installed: $success_count"
    echo "Failed: $fail_count"
    echo "=============================================="
    
    if [ $fail_count -eq 0 ]; then
        echo "🎵 All audio models installed successfully!"
        return 0
    else
        echo "⚠️  Some audio models failed to install. Check the log for details."
        return 1
    fi
}

# Function to install MusicGen models
install_musicgen_model() {
    local model_name="$1"
    local repo_id="$2"
    
    echo "🎼 Installing MusicGen model: $model_name ($repo_id)"
    
    # Create model-specific directory
    local model_dir="$HERE/../AudioModels/musicgen/$model_name"
    mkdir -p "$model_dir"
    
    # Use external Python template script
    local template_script="$HERE/AudioTemplates/install_musicgen.py"
    if [ -f "$template_script" ]; then
        ${PYTHON_CMD:-python3} "$template_script" "$model_name" "$repo_id" "$model_dir"
    else
        echo "❌ Template script not found: $template_script"
        return 1
    fi
    return $?
}

# Function to install TTS models
install_tts_model() {
    local model_name="$1"
    local repo_id="$2"
    
    echo "🗣️  Installing TTS model: $model_name ($repo_id)"
    
    # Create model-specific directory
    local model_dir="$HERE/../AudioModels/tts/$model_name"
    mkdir -p "$model_dir"
    
    # Use external Python template script
    local template_script="$HERE/AudioTemplates/install_tts.py"
    if [ -f "$template_script" ]; then
        ${PYTHON_CMD:-python3} "$template_script" "$model_name" "$repo_id" "$model_dir"
    else
        echo "❌ Template script not found: $template_script"
        return 1
    fi
    return $?
}

# Function to install Bark models
install_bark_model() {
    local model_name="$1"
    local repo_id="$2"
    
    echo "🐕 Installing Bark model: $model_name ($repo_id)"
    
    # Create model-specific directory
    local model_dir="$HERE/../AudioModels/bark/$model_name"
    mkdir -p "$model_dir"
    
    # Use external Python template script
    local template_script="$HERE/AudioTemplates/install_bark.py"
    if [ -f "$template_script" ]; then
        ${PYTHON_CMD:-python3} "$template_script" "$model_name" "$repo_id" "$model_dir"
    else
        echo "❌ Template script not found: $template_script"
        return 1
    fi
    return $?
}

# Function to create audio model usage scripts
create_usage_scripts() {
    echo "📝 Creating audio model usage scripts..."
    
    local scripts_dir="$HERE/../AudioModels/scripts"
    mkdir -p "$scripts_dir"
    
    # Copy template scripts from AudioTemplates
    local music_template="$HERE/AudioTemplates/generate_music.py"
    local tts_template="$HERE/AudioTemplates/text_to_speech.py"
    
    if [ -f "$music_template" ]; then
        cp "$music_template" "$scripts_dir/generate_music.py"
        chmod +x "$scripts_dir/generate_music.py"
        echo "✅ MusicGen script created from template"
    else
        echo "❌ Music generation template not found: $music_template"
        return 1
    fi
    
    if [ -f "$tts_template" ]; then
        cp "$tts_template" "$scripts_dir/text_to_speech.py"
        chmod +x "$scripts_dir/text_to_speech.py"
        echo "✅ TTS script created from template"
    else
        echo "❌ TTS template not found: $tts_template"
        return 1
    fi
    
    echo "✅ Usage scripts created in $scripts_dir/"
}

# Main execution
main() {
    local CATEGORY="$1"
    
    if [ -z "$CATEGORY" ]; then
        echo "❌ Usage: $0 <category>"
        echo "   Example: $0 Generative/Audio"
        exit 1
    fi
    
    # Install dependencies
    install_audio_dependencies
    
    # Determine VRAM and select appropriate models
    echo "🔍 Detecting system capabilities..."
    
    # Get VRAM info (same logic as original script)
    if command -v nvidia-smi &> /dev/null; then
        vram_info=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
        vram_info_gb=$(echo "scale=1; $vram_info / 1024" | bc -l)
        echo "GPU VRAM: ${vram_info_gb} GB"
    else
        echo "No NVIDIA GPU detected, using CPU-friendly models"
        vram_info_gb=0
    fi
    
    # Select model size based on VRAM
    if (( $(echo "$vram_info_gb >= 24" | bc -l) )); then
        MODEL_SIZE="70B"
        echo "🚀 High-end GPU detected. Using largest audio models."
    elif (( $(echo "$vram_info_gb >= 12" | bc -l) )); then
        MODEL_SIZE="34B"
        echo "💪 Good GPU detected. Using large audio models."
    elif (( $(echo "$vram_info_gb >= 8" | bc -l) )); then
        MODEL_SIZE="13B"
        echo "👍 Decent GPU detected. Using medium audio models."
    else
        MODEL_SIZE="7B"
        echo "💻 Limited GPU/CPU setup. Using small audio models."
    fi
    
    MODELS_FILE="$HERE/Recipes/Models/$CATEGORY/$MODEL_SIZE"
    
    if [ ! -f "$MODELS_FILE" ]; then
        echo "❌ Models file not found: $MODELS_FILE"
        exit 1
    fi
    
    # Install the models
    if install_audio_models "$MODELS_FILE"; then
        echo "🎵 Audio models installation completed!"
        
        # Create usage scripts
        create_usage_scripts
        
        echo ""
        echo "📋 Usage Examples:"
        echo "  Generate Music: python3 ../AudioModels/scripts/generate_music.py 'happy upbeat electronic music'"
        echo "  Text to Speech: python3 ../AudioModels/scripts/text_to_speech.py 'Hello, this is a test'"
        echo ""
        echo "🎯 Audio models are ready for use!"
        
        return 0
    else
        echo "❌ Audio models installation failed!"
        return 1
    fi
}

# Execute main function with all arguments
main "$@"