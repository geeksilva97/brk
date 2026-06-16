#!/bin/bash
# Session start — inject tutoring context
DIR="$(cd "$(dirname "$0")/.." && pwd)"
STEP=$("$DIR/bin/dojo.sh" get)
TITLE=$("$DIR/bin/dojo.sh" title)
SPINE=$("$DIR/bin/dojo.sh" spine)

echo "System Design Interview Dojo — Step $STEP: $TITLE"
echo "Current task: $SPINE"
echo "Type /systeminterview:start to begin, /systeminterview:next to advance"