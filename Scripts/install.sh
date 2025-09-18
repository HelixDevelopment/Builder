#!/bin/bash

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! which ollama > /dev/null 2>&1; then
    if "$HERE/install_ollama.sh"; then
        if "$HERE/configure_ollama.sh"; then
            echo "Ollama is ready"
        else
            echo "ERROR: Failed to configure Ollama"
            exit 1
        fi
    else
        echo "ERROR: Failed to install Ollama"
        exit 1
    fi
fi

if "$HERE/install_ollama_webui.sh"; then
    echo "Installation completed"
else
    echo "ERROR: Installation failed"
    exit 1
fi

# Check if this is an audio category and redirect to audio installer
if [[ "$1" == *"Audio"* ]]; then
    echo "🎵 Detected audio category, using specialized audio installer..."
    
    if "$HERE/install_audio_models.sh" "$1"; then
        echo "🎵 Audio models have been installed successfully"
        echo "ℹ️  Note: Audio models run independently of Ollama/WebUI"
        echo "📋 Use the provided Python scripts to generate audio content"
    else
        echo "ERROR: Failed to install audio models"
        exit 1
    fi
else
    # Use standard Ollama installer for non-audio categories
    if "$HERE/install_ollama_models.sh" "$1"; then
        echo "Models have been installed with success"
        
        if docker container restart open-webui > /dev/null 2>&1; then
            echo "Open WebUI is ready to use the new models"
        else
            echo "ERROR: Open WebUI failed to restart"
            exit 1
        fi
    else
        echo "ERROR: Failed to install models"
        exit 1
    fi
fi