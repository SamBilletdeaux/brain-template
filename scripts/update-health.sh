#!/bin/bash
# update-health.sh - Update health.md with wind-down metrics
#
# Usage:
#   ./scripts/update-health.sh [brain-root] [options]
#
# Options (passed as key=value):
#   date=YYYY-MM-DD          Date of this wind-down (default: today)
#   meetings=N               Number of meetings processed
#   words=N                  Approximate transcript word count
#   mode=full|triage         Processing mode used
#   decisions_green=N        High-confidence decisions
#   decisions_yellow=N       Medium-confidence decisions
#   decisions_red=N          Low-confidence decisions
#   corrections=N            Number of user corrections
#   new_rules=N              New preference rules added
#
# Thread/people/rule counts are computed automatically from the brain directory.

BRAIN_ROOT="${1:-$HOME/brain}"
HEALTH_FILE="$BRAIN_ROOT/health.md"

if [ ! -f "$HEALTH_FILE" ]; then
    echo "Error: health.md not found at $HEALTH_FILE" >&2
    exit 1
fi

shift 2>/dev/null  # shift past brain root

# Defaults
DATE=$(date +%Y-%m-%d)
MEETINGS=0
WORDS=0
MODE="full"
D_GREEN=0
D_YELLOW=0
D_RED=0
CORRECTIONS=0
NEW_RULES=0

# Parse key=value arguments
for ARG in "$@"; do
    KEY="${ARG%%=*}"
    VAL="${ARG#*=}"
    case "$KEY" in
        date) DATE="$VAL" ;;
        meetings) MEETINGS="$VAL" ;;
        words) WORDS="$VAL" ;;
        mode) MODE="$VAL" ;;
        decisions_green) D_GREEN="$VAL" ;;
        decisions_yellow) D_YELLOW="$VAL" ;;
        decisions_red) D_RED="$VAL" ;;
        corrections) CORRECTIONS="$VAL" ;;
        new_rules) NEW_RULES="$VAL" ;;
        *) echo "Unknown option: $KEY" >&2 ;;
    esac
done

# Compute counts from brain directory
ACTIVE_THREADS=$(find "$BRAIN_ROOT/threads" -name "*.md" 2>/dev/null | wc -l | xargs)
DORMANT_THREADS=0  # TODO: parse status from thread files
PEOPLE_COUNT=$(find "$BRAIN_ROOT/people" -name "*.md" 2>/dev/null | wc -l | xargs)
TOTAL_DECISIONS=$((D_GREEN + D_YELLOW + D_RED))

# Compute days since last wind-down
LAST_DATE=$(grep '^\- \*\*Date\*\*:' "$HEALTH_FILE" | head -1 | sed 's/.*: *//')
if [ -n "$LAST_DATE" ] && [ "$LAST_DATE" != "(not yet run)" ]; then
    LAST_EPOCH=$(date -j -f "%Y-%m-%d" "$LAST_DATE" "+%s" 2>/dev/null)
    CURR_EPOCH=$(date -j -f "%Y-%m-%d" "$DATE" "+%s" 2>/dev/null)
    if [ -n "$LAST_EPOCH" ] && [ -n "$CURR_EPOCH" ]; then
        DAYS_SINCE=$(( (CURR_EPOCH - LAST_EPOCH) / 86400 ))
    else
        DAYS_SINCE=0
    fi
else
    DAYS_SINCE="N/A (first run)"
fi

# Count preference rules
PREF_RULES=$(grep -c '^- ' "$BRAIN_ROOT/preferences.md" 2>/dev/null || echo 0)

# Compute consecutive days (read from previous Latest Run)
PREV_CONSECUTIVE=$(grep 'Consecutive days' "$HEALTH_FILE" | head -1 | sed 's/.*: *//')
if [ "$DAYS_SINCE" = "1" ]; then
    CONSECUTIVE=$((PREV_CONSECUTIVE + 1))
elif [ "$DAYS_SINCE" = "N/A (first run)" ]; then
    CONSECUTIVE=1
else
    CONSECUTIVE=1
fi

# Build the new Latest Run block
NEW_LATEST="## Latest Run
<!-- Updated automatically by /wind-down Phase 6 -->

- **Date**: $DATE
- **Meetings processed**: $MEETINGS
- **Transcript volume**: ~${WORDS} words
- **Processing mode**: $MODE
- **Decisions made**: $TOTAL_DECISIONS (🟢: $D_GREEN, 🟡: $D_YELLOW, 🔴: $D_RED)
- **Corrections received**: $CORRECTIONS
- **New preferences rules added**: $NEW_RULES
- **Active threads**: $ACTIVE_THREADS
- **Dormant threads**: $DORMANT_THREADS
- **People files**: $PEOPLE_COUNT
- **Preferences rule count**: $PREF_RULES
- **Days since last wind-down**: $DAYS_SINCE
- **Consecutive days run**: $CONSECUTIVE"

# Build the new history row
NEW_ROW="| $DATE | $MEETINGS | ~${WORDS} | $MODE | $TOTAL_DECISIONS ($D_GREEN/$D_YELLOW/$D_RED) | $CORRECTIONS | $ACTIVE_THREADS/$DORMANT_THREADS | $PEOPLE_COUNT | $PREF_RULES |"

# Check if today's entry already exists (idempotent)
if grep -q "| $DATE |" "$HEALTH_FILE"; then
    # Update existing row
    python3 -c "
import re, sys
with open('$HEALTH_FILE', 'r') as f:
    content = f.read()

# Replace Latest Run block
latest_pattern = r'## Latest Run.*?(?=\n## )'
new_latest = '''$NEW_LATEST

'''
content = re.sub(latest_pattern, new_latest, content, flags=re.DOTALL)

# Replace existing row for this date
content = re.sub(r'\| $DATE \|.*\n', '$NEW_ROW\n', content)

with open('$HEALTH_FILE', 'w') as f:
    f.write(content)
"
    echo "Updated existing health entry for $DATE"
else
    # Replace Latest Run block and append new history row
    python3 -c "
import re
with open('$HEALTH_FILE', 'r') as f:
    content = f.read()

# Replace Latest Run block
latest_pattern = r'## Latest Run.*?(?=\n## )'
new_latest = '''$NEW_LATEST

'''
content = re.sub(latest_pattern, new_latest, content, flags=re.DOTALL)

# Remove placeholder row if present
content = content.replace('| (no entries yet) | | | | | | | | |\n', '')

# Append new row after header row
header_pattern = r'(\|---.*\|)\n'
content = re.sub(header_pattern, r'\1\n$NEW_ROW\n', content)

with open('$HEALTH_FILE', 'w') as f:
    f.write(content)
"
    echo "Added new health entry for $DATE"
fi
