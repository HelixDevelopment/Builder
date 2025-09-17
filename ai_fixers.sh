#!/bin/bash

# Forward all commands and arguments to Scripts/AutoFixers/autofix_manager.py
exec "$(dirname "$0")/Scripts/AutoFixers/autofix_manager.py" "$@"