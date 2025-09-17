#!/bin/bash

# Forward all commands and arguments to Scripts/test_working.sh
exec "$(dirname "$0")/Scripts/test_working.sh" "$@"