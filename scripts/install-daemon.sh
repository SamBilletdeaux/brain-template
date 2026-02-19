#!/bin/bash
# install-daemon.sh - Install the transcript snapshotter as a launchd service
#
# Usage:
#   ./scripts/install-daemon.sh [brain-root] [scripts-dir]
#
# Installs a launchd agent that runs snapshot-transcripts.sh every 30 minutes.
# The service starts immediately and runs on login.

BRAIN_ROOT="${1:-$HOME/brain}"
SCRIPTS_DIR="${2:-$(cd "$(dirname "$0")" && pwd)}"
PLIST_NAME="com.brain.transcript-snapshotter"
PLIST_SRC="$SCRIPTS_DIR/$PLIST_NAME.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
LOG_FILE="/tmp/brain-snapshotter.log"

if [ ! -f "$PLIST_SRC" ]; then
    echo "Error: Plist template not found at $PLIST_SRC" >&2
    exit 1
fi

# Unload if already running
if launchctl list | grep -q "$PLIST_NAME" 2>/dev/null; then
    echo "Stopping existing service..."
    launchctl unload "$PLIST_DST" 2>/dev/null
fi

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Create inbox directory
mkdir -p "$BRAIN_ROOT/inbox/granola"

# Generate plist with correct paths baked in
cat > "$PLIST_DST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPTS_DIR/snapshot-transcripts.sh</string>
        <string>$BRAIN_ROOT</string>
    </array>

    <key>StartInterval</key>
    <integer>1800</integer>

    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>

    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>

    <key>RunAtLoad</key>
    <true/>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
PLIST

# Load the service
launchctl load "$PLIST_DST"

echo "Transcript snapshotter installed and running."
echo "  Service: $PLIST_NAME"
echo "  Interval: every 30 minutes"
echo "  Brain root: $BRAIN_ROOT"
echo "  Log file: $LOG_FILE"
echo ""
echo "To check status: launchctl list | grep brain"
echo "To view logs:    tail -f $LOG_FILE"
echo "To uninstall:    ./scripts/uninstall-daemon.sh"
