#!/bin/bash
# pick-files.sh - Open a native macOS file picker for selecting multiple files
# Returns selected file paths, one per line

PROMPT="${1:-Select files:}"

# Open native macOS file picker with multiple selection
SELECTED=$(osascript -e "choose file with prompt \"$PROMPT\" with multiple selections allowed" 2>/dev/null)

# Check if user cancelled
if [ -z "$SELECTED" ]; then
    echo "No files selected." >&2
    exit 1
fi

# Convert AppleScript paths to POSIX paths
# Input:  alias Macintosh HD:Users:sam:file.txt, alias Macintosh HD:Users:sam:other.txt
# Output: /Users/sam/file.txt
#         /Users/sam/other.txt

echo "$SELECTED" | tr ',' '\n' | while read -r line; do
    # Remove "alias Macintosh HD:" or similar prefix, convert : to /
    echo "$line" | sed 's/^ *//; s/alias [^:]*:/\//; s/:/\//g'
done
