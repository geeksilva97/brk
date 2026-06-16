#!/bin/bash
# Update session title on step changes
DIR="$(cd "$(dirname "$0")/.." && pwd)"
STEP=$("$DIR/bin/dojo.sh" get)
TITLE=$("$DIR/bin/dojo.sh" title)
echo "systeminterview - Step $STEP: $TITLE"