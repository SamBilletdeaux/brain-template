#!/bin/bash
# uninstall-daemon.sh - Remove the transcript snapshotter launchd service
#
# Usage:
#   ./scripts/uninstall-daemon.sh

PLIST_NAME="com.brain.transcript-snapshotter"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

if [ ! -f "$PLIST_DST" ]; then
    echo "Service not installed (no plist at $PLIST_DST)"
    exit 0
fi

launchctl unload "$PLIST_DST" 2>/dev/null
rm -f "$PLIST_DST"

echo "Transcript snapshotter uninstalled."
echo "  Inbox data at ~/brain/inbox/granola/ has been preserved."
