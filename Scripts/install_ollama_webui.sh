#!/bin/bash

if ! which docker; then

    if ! ./install_docker.sh; then

        echo "ERROR: Please install Docker"
        exit 1
    fi
fi

if [ -z "$1" ]; then

    PORT="8085"

else

    PORT="$1"
fi

if docker run -d -p "$PORT":"$PORT" --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui ghcr.io/open-webui/open-webui:main; then

    echo "Installation completed, running at port: $PORT"

else

    echo "ERROR: Installation failed"
    exit 1
fi
