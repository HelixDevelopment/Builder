#!/bin/bash

# Forward all commands and arguments to Scripts/test.sh
exec "$(dirname "$0")/Scripts/test.sh" "$@"