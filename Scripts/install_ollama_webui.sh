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
