#!/bin/bash

# Forward all commands and arguments to Scripts/memory_cli.sh
exec "$(dirname "$0")/Scripts/memory_cli.sh" "$@"