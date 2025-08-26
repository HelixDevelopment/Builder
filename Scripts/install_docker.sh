#!/bin/bash

if sudo apt update && sudo apt install docker.io && \
    sudo systemctl enable --now docker && \
    sudo usermod -aG docker $USER; then

    echo "Installation completed, Docker is ready"
    echo "Please log out and back in for the group change to take effect!"

else

    echo "ERROR: Docker installation failed"
    exit 1
fi
