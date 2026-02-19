#!/bin/bash
# uninstall-notifications.sh — Remove brain notification services

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

for LABEL in com.brain.winddown-reminder com.brain.stale-check com.brain.meeting-prep; do
    PLIST="$LAUNCH_AGENTS/$LABEL.plist"
    if [ -f "$PLIST" ]; then
        launchctl unload "$PLIST" 2>/dev/null
        rm -f "$PLIST"
        echo "Removed: $LABEL"
    fi
done

echo "All notification services removed."
