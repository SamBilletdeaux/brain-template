#!/bin/bash
# notify.sh — Send macOS notifications from the brain system
#
# Usage:
#   ./scripts/notify.sh "title" "message"
#   ./scripts/notify.sh "title" "message" --sound
#   ./scripts/notify.sh --check-winddown [brain-root]
#   ./scripts/notify.sh --check-stale [brain-root]
#
# The --check-* modes are designed to be called by launchd on a schedule.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

send_notification() {
    local TITLE="$1"
    local MESSAGE="$2"
    local SOUND="${3:-}"

    local SOUND_CMD=""
    if [ "$SOUND" = "--sound" ]; then
        SOUND_CMD='sound name "Glass"'
    fi

    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" $SOUND_CMD" 2>/dev/null
}

# Direct notification mode
if [ "$1" != "--check-winddown" ] && [ "$1" != "--check-stale" ] && [ "$1" != "--check-prep" ]; then
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: notify.sh \"title\" \"message\" [--sound]"
        exit 1
    fi
    send_notification "$1" "$2" "$3"
    exit 0
fi

MODE="$1"
BRAIN_ROOT="${2:-$HOME/brain}"

case "$MODE" in
    --check-winddown)
        # Check if wind-down has been run today
        HEALTH_FILE="$BRAIN_ROOT/health.md"
        if [ ! -f "$HEALTH_FILE" ]; then
            send_notification "Brain" "Wind-down reminder: health.md not found" --sound
            exit 0
        fi

        TODAY=$(date +%Y-%m-%d)
        LAST_DATE=$(grep '^\- \*\*Date\*\*:' "$HEALTH_FILE" | head -1 | sed 's/.*: *//')

        if [ "$LAST_DATE" != "$TODAY" ]; then
            send_notification "Brain: Wind-Down" "You haven't processed today's meetings yet. Run /wind-down before bed." --sound
        fi
        ;;

    --check-stale)
        # Check for stale commitments (>5 days old)
        COMMITMENTS_FILE="$BRAIN_ROOT/commitments.md"
        if [ ! -f "$COMMITMENTS_FILE" ]; then
            exit 0
        fi

        TODAY_EPOCH=$(date +%s)
        STALE_THRESHOLD=$((5 * 86400))
        STALE_COUNT=0

        while IFS= read -r line; do
            DATE_MATCH=$(echo "$line" | grep -oE 'added [0-9]{4}-[0-9]{2}-[0-9]{2}' | sed 's/added //')
            if [ -n "$DATE_MATCH" ]; then
                COMMIT_EPOCH=$(date -j -f "%Y-%m-%d" "$DATE_MATCH" "+%s" 2>/dev/null)
                if [ -n "$COMMIT_EPOCH" ]; then
                    AGE=$(( TODAY_EPOCH - COMMIT_EPOCH ))
                    if [ "$AGE" -gt "$STALE_THRESHOLD" ]; then
                        STALE_COUNT=$((STALE_COUNT + 1))
                    fi
                fi
            fi
        done < <(grep '^\- \[ \]' "$COMMITMENTS_FILE")

        if [ "$STALE_COUNT" -gt 0 ]; then
            send_notification "Brain: Stale Items" "$STALE_COUNT commitment(s) older than 5 days. Run /doctor to review." --sound
        fi
        ;;

    --check-prep)
        # Generate prep for upcoming meetings (called before meeting block)
        PREP_DIR="$BRAIN_ROOT/inbox/prep"
        TODAY=$(date +%Y-%m-%d)

        # Check if prep already exists for today
        if ls "$PREP_DIR/$TODAY"*.md 1>/dev/null 2>&1; then
            exit 0  # already generated
        fi

        # Generate prep
        python3 "$SCRIPT_DIR/generate-prep.py" "$BRAIN_ROOT" --hours-ahead 4 2>/dev/null
        PREP_COUNT=$(ls "$PREP_DIR/$TODAY"*.md 2>/dev/null | wc -l | xargs)

        if [ "$PREP_COUNT" -gt 0 ]; then
            send_notification "Brain: Meeting Prep" "$PREP_COUNT prep packet(s) ready. Check localhost:3141/prep" --sound
        fi
        ;;
esac
