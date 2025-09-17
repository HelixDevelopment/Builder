#!/bin/bash

# Forward all commands and arguments to Scripts/debug_test.sh
exec "$(dirname "$0")/Scripts/debug_test.sh" "$@"