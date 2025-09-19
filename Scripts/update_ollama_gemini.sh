#!/bin/bash

cd gemini-cli-ollama && \
    git fetch && \
    git pull && \
    git submodule init && \
    git submodule update && \
    rm -rf ./node_modules && \
    npm install && \
    npm run build && \
    sudo npm install -g . \
    gemini --version