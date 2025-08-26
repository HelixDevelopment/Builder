#!/bin/bash

# FIXME: Verify the binding with local Ollama instance

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! which docker; then

    if "$HERE"/install_docker.sh; then

        echo "After re-login please run the script again."
        exit 0

    else

        echo "ERROR: Please install Docker"
        exit 1
    fi
fi

if [ -z "$1" ]; then

    PORT="8085"

else

    PORT="$1"
fi

if docker run -d -p "$PORT":8080 --network=host -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://127.0.0.1:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main; then

    echo "Installation completed, running at port: $PORT"

else

    echo "ERROR: Installation failed"
    exit 1
fi
