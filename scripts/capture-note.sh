#!/bin/bash
# capture-note.sh - Quick-capture a thought to the inbox
#
# Usage:
#   ./scripts/capture-note.sh "some thought about the AISP meeting"
#   ./scripts/capture-note.sh                    # opens $EDITOR for longer notes
#
# Drops a timestamped markdown file into inbox/notes/ for the next wind-down
# to process and route to the appropriate thread.
#
# Tip: alias note="~/brain-template/scripts/capture-note.sh"

BRAIN_ROOT="${BRAIN_ROOT:-$HOME/brain}"
NOTES_DIR="$BRAIN_ROOT/inbox/notes"
TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
FILENAME="$NOTES_DIR/$TIMESTAMP.md"

mkdir -p "$NOTES_DIR"

if [ -n "$1" ]; then
    # Inline note from arguments
    NOTE_TEXT="$*"
    cat > "$FILENAME" << EOF
---
captured: $(date '+%Y-%m-%d %H:%M:%S')
---

$NOTE_TEXT
EOF
    echo "Captured to $FILENAME"
else
    # No argument — open editor for longer notes
    EDITOR="${EDITOR:-nano}"
    TEMP=$(mktemp)
    cat > "$TEMP" << EOF
---
captured: $(date '+%Y-%m-%d %H:%M:%S')
---

EOF
    $EDITOR "$TEMP"

    # Check if user wrote anything beyond the frontmatter
    CONTENT=$(sed '/^---$/,/^---$/d' "$TEMP" | tr -d '[:space:]')
    if [ -z "$CONTENT" ]; then
        echo "Empty note, discarded."
        rm -f "$TEMP"
        exit 0
    fi

    mv "$TEMP" "$FILENAME"
    echo "Captured to $FILENAME"
fi
