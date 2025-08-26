#!/bin/bash

# TODO: Make sure it binds to 0.0.0.0 and open Firewall ports

if curl -fsSL https://ollama.ai/install.sh | sh && \
    sudo systemctl start ollama && \
    sudo systemctl enable ollama; then

    echo "Installation completed, Ollama is ready"

else

    echo "ERROR: Ollama installation failed"
    exit 1
fi
