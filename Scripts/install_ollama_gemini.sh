#!/bin/bash

git clone https://github.com/MichaelLeib/gemini-cli-ollama.git ./gemini-cli-ollama && \
    cd gemini-cli-ollama && \
    npm install && \
    npm run build && \
    sudo npm install -g . \
    gemini --version