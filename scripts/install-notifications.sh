#!/bin/bash
# install-notifications.sh — Install brain notification services
#
# Installs two launchd agents:
#   1. Wind-down reminder at 8pm if not yet run today
#   2. Stale commitment check at 9am daily
#   3. Meeting prep generation at 8am and 12pm

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRAIN_ROOT="${1:-$HOME/brain}"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

mkdir -p "$LAUNCH_AGENTS"

# --- Wind-down reminder (8pm daily) ---
WINDDOWN_PLIST="$LAUNCH_AGENTS/com.brain.winddown-reminder.plist"
cat > "$WINDDOWN_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.brain.winddown-reminder</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/notify.sh</string>
        <string>--check-winddown</string>
        <string>$BRAIN_ROOT</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>20</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
EOF
launchctl unload "$WINDDOWN_PLIST" 2>/dev/null
launchctl load "$WINDDOWN_PLIST"
echo "Installed: wind-down reminder (8pm daily)"

# --- Stale commitment check (9am daily) ---
STALE_PLIST="$LAUNCH_AGENTS/com.brain.stale-check.plist"
cat > "$STALE_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.brain.stale-check</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/notify.sh</string>
        <string>--check-stale</string>
        <string>$BRAIN_ROOT</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
EOF
launchctl unload "$STALE_PLIST" 2>/dev/null
launchctl load "$STALE_PLIST"
echo "Installed: stale commitment check (9am daily)"

# --- Meeting prep (8am and 12pm) ---
PREP_PLIST="$LAUNCH_AGENTS/com.brain.meeting-prep.plist"
cat > "$PREP_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.brain.meeting-prep</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/notify.sh</string>
        <string>--check-prep</string>
        <string>$BRAIN_ROOT</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key>
            <integer>8</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>12</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </array>
</dict>
</plist>
EOF
launchctl unload "$PREP_PLIST" 2>/dev/null
launchctl load "$PREP_PLIST"
echo "Installed: meeting prep generator (8am + 12pm daily)"

echo ""
echo "All notification services installed."
echo "To uninstall: ./scripts/uninstall-notifications.sh"
