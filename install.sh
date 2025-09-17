#!/bin/bash

# Forward all commands and arguments to Scripts/install.sh
exec "$(dirname "$0")/Scripts/install.sh" "$@"