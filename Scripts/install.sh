#!/bin/bash

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! which ollama; then

    if ! "$HERE"/install_ollama.sh; then

        echo "ERROR: Please install Docker"
        exit 1
    fi
fi

if "$HERE"/install_ollama_webui.sh; then

    echo "Installation completed"

else

    echo "ERROR: Installation failed"
    exit 1
fi
