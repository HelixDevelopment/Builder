#!/bin/bash

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! which ollama; then

    if "$HERE"/install_ollama.sh; then

        if "$HERE"/configure_ollama.sh; then

            echo "Ollama is ready"

        else

            echo "ERROR: Failed to configure Ollama"
            exit 1
        fi

    fi

        echo "ERROR: Failed to install Ollama"
        exit 1
    fi
fi

if "$HERE"/install_ollama_webui.sh; then

    echo "Installation completed"

else

    echo "ERROR: Installation failed"
    exit 1
fi

if "$HERE/install_ollama_models.sh"; then

    echo "Models have been installed wth success"

else

    echo "ERROR: Failed to install models"
    exit 1
fi