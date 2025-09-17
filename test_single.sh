#!/bin/bash

# Forward all commands and arguments to Scripts/test_single.sh
exec "$(dirname "$0")/Scripts/test_single.sh" "$@"