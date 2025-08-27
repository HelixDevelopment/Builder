#!/bin/bash

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

    export PORT="8085"

else

    export PORT="$1"
fi

if docker run -d \
  -p $PORT:8080 \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://$(hostname -I | awk '{print $1}'):11434 \
  --add-host="$hostname".local:host-gateway \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main; then

    echo "Installation completed! Open WebUI is now running on port: $PORT"
    echo "You can access it at: http://$(hostname -I | awk '{print $1}'):$PORT"
    echo "or at: http://localhost:$PORT on this machine."

else

    echo "ERROR: Installation failed. Please check your Docker setup and try again."
    exit 1
fi
