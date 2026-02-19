#!/bin/bash
# archive.sh - Archive old handoff entries, completed commitments, and dormant threads
#
# Usage:
#   ./scripts/archive.sh [brain-root] [--dry-run]
#
# What it does:
#   - Moves handoff entries older than 90 days to archive/handoffs/YYYY-QN.md
#   - Moves completed commitments older than 30 days to archive/commitments/YYYY.md
#   - Lists dormant threads (>30 days) for human confirmation (never auto-archives threads)
#
# Options:
#   --dry-run    Show what would be archived without making changes

BRAIN_ROOT="${1:-$HOME/brain}"
DRY_RUN=false

for ARG in "$@"; do
    [ "$ARG" = "--dry-run" ] && DRY_RUN=true
done

HANDOFF_FILE="$BRAIN_ROOT/handoff.md"
COMMITMENTS_FILE="$BRAIN_ROOT/commitments.md"
THREADS_DIR="$BRAIN_ROOT/threads"
ARCHIVE_DIR="$BRAIN_ROOT/archive"

TODAY=$(date +%Y-%m-%d)
TODAY_EPOCH=$(date -j -f "%Y-%m-%d" "$TODAY" "+%s" 2>/dev/null)

# Determine quarter from a date
quarter_for_date() {
    local month=$(echo "$1" | cut -d'-' -f2)
    local year=$(echo "$1" | cut -d'-' -f1)
    case "$month" in
        01|02|03) echo "${year}-Q1" ;;
        04|05|06) echo "${year}-Q2" ;;
        07|08|09) echo "${year}-Q3" ;;
        10|11|12) echo "${year}-Q4" ;;
    esac
}

# Calculate days between two dates
days_between() {
    local d1=$(date -j -f "%Y-%m-%d" "$1" "+%s" 2>/dev/null)
    local d2=$(date -j -f "%Y-%m-%d" "$2" "+%s" 2>/dev/null)
    if [ -n "$d1" ] && [ -n "$d2" ]; then
        echo $(( (d2 - d1) / 86400 ))
    else
        echo 0
    fi
}

echo "=== Brain Archival ==="
echo "Brain root: $BRAIN_ROOT"
echo "Date: $TODAY"
[ "$DRY_RUN" = true ] && echo "MODE: DRY RUN (no changes will be made)"
echo ""

# --- 1. Archive old handoff entries ---
echo "--- Handoff Entries ---"

if [ ! -f "$HANDOFF_FILE" ]; then
    echo "No handoff.md found, skipping."
else
    # Extract dates of handoff entries (## YYYY-MM-DD format)
    HANDOFF_DATES=$(grep -E '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$HANDOFF_FILE" | sed 's/^## //' | sed 's/ .*//')
    OLD_COUNT=0

    for ENTRY_DATE in $HANDOFF_DATES; do
        AGE=$(days_between "$ENTRY_DATE" "$TODAY")
        if [ "$AGE" -gt 90 ]; then
            OLD_COUNT=$((OLD_COUNT + 1))
            QUARTER=$(quarter_for_date "$ENTRY_DATE")
            echo "  Old: $ENTRY_DATE ($AGE days) → archive/handoffs/${QUARTER}.md"
        fi
    done

    if [ "$OLD_COUNT" -eq 0 ]; then
        echo "  No entries older than 90 days."
    elif [ "$DRY_RUN" = false ]; then
        # Extract and move old entries using Python for reliable markdown parsing
        python3 -c "
import re, os, sys
from datetime import datetime, timedelta

brain_root = '$BRAIN_ROOT'
handoff_path = '$HANDOFF_FILE'
archive_dir = os.path.join(brain_root, 'archive', 'handoffs')
os.makedirs(archive_dir, exist_ok=True)

with open(handoff_path, 'r') as f:
    content = f.read()

cutoff = datetime.strptime('$TODAY', '%Y-%m-%d') - timedelta(days=90)

# Split into entries by ## headers with dates
pattern = r'(## \d{4}-\d{2}-\d{2}.*?)(?=\n## \d{4}-\d{2}-\d{2}|\Z)'
entries = re.findall(pattern, content, re.DOTALL)

keep = []
archive = {}  # quarter -> list of entries

for entry in entries:
    date_match = re.match(r'## (\d{4}-\d{2}-\d{2})', entry)
    if date_match:
        entry_date = datetime.strptime(date_match.group(1), '%Y-%m-%d')
        if entry_date < cutoff:
            month = entry_date.month
            year = entry_date.year
            q = (month - 1) // 3 + 1
            quarter = f'{year}-Q{q}'
            archive.setdefault(quarter, []).append(entry.strip())
        else:
            keep.append(entry.strip())
    else:
        keep.append(entry.strip())

# Write archived entries to quarter files
for quarter, entries_list in sorted(archive.items()):
    quarter_file = os.path.join(archive_dir, f'{quarter}.md')
    header = f'# Archived Handoff Entries — {quarter}\n\n'
    existing = ''
    if os.path.exists(quarter_file):
        with open(quarter_file, 'r') as f:
            existing = f.read()
    with open(quarter_file, 'w') as f:
        if existing:
            f.write(existing.rstrip() + '\n\n')
        else:
            f.write(header)
        for e in entries_list:
            f.write(e + '\n\n')
    print(f'  Wrote {len(entries_list)} entries to archive/handoffs/{quarter}.md')

# Rewrite handoff.md with only recent entries
# Preserve the header (everything before first ## date entry)
header_match = re.match(r'(.*?)(?=## \d{4}-\d{2}-\d{2})', content, re.DOTALL)
header = header_match.group(1) if header_match else '# Handoff\n\n'

with open(handoff_path, 'w') as f:
    f.write(header)
    for e in keep:
        f.write(e + '\n\n')

total_archived = sum(len(v) for v in archive.values())
print(f'  Archived {total_archived} entries, kept {len(keep)}')
"
    fi
fi

echo ""

# --- 2. Archive completed commitments ---
echo "--- Completed Commitments ---"

if [ ! -f "$COMMITMENTS_FILE" ]; then
    echo "No commitments.md found, skipping."
else
    # Count completed items
    COMPLETED_COUNT=$(grep -c '^\- \[x\]' "$COMMITMENTS_FILE" 2>/dev/null)
    COMPLETED_COUNT=${COMPLETED_COUNT:-0}

    if [ "$COMPLETED_COUNT" -eq 0 ]; then
        echo "  No completed commitments to archive."
    else
        # Find completed items older than 30 days
        echo "  Found $COMPLETED_COUNT completed commitments."

        if [ "$DRY_RUN" = false ]; then
            python3 -c "
import re, os
from datetime import datetime, timedelta

brain_root = '$BRAIN_ROOT'
commit_path = '$COMMITMENTS_FILE'
archive_dir = os.path.join(brain_root, 'archive', 'commitments')
os.makedirs(archive_dir, exist_ok=True)

with open(commit_path, 'r') as f:
    content = f.read()

cutoff = datetime.strptime('$TODAY', '%Y-%m-%d') - timedelta(days=30)

# Find the Completed section
completed_match = re.search(r'## Completed\n.*?\n(.*?)$', content, re.DOTALL)
if not completed_match:
    print('  No Completed section found.')
    exit(0)

completed_text = completed_match.group(1)
lines = completed_text.strip().split('\n')

keep = []
archive = []

for line in lines:
    line = line.strip()
    if not line or line.startswith('(') or line.startswith('<!--'):
        continue
    # Try to find a date in the line
    date_match = re.search(r'(\d{4}-\d{2}-\d{2})', line)
    if date_match:
        item_date = datetime.strptime(date_match.group(1), '%Y-%m-%d')
        if item_date < cutoff:
            archive.append(line)
        else:
            keep.append(line)
    else:
        keep.append(line)  # No date = keep (can't determine age)

if not archive:
    print('  No completed commitments older than 30 days.')
    exit(0)

# Write archived items
year = datetime.strptime('$TODAY', '%Y-%m-%d').year
archive_file = os.path.join(archive_dir, f'{year}.md')
header = f'# Archived Commitments — {year}\n\n'
existing = ''
if os.path.exists(archive_file):
    with open(archive_file, 'r') as f:
        existing = f.read()
with open(archive_file, 'w') as f:
    if existing:
        f.write(existing.rstrip() + '\n')
    else:
        f.write(header)
    for item in archive:
        f.write(item + '\n')

# Update commitments.md — replace Completed section
if keep:
    new_completed = '\n'.join(keep)
else:
    new_completed = '(Nothing yet.)'

new_content = content[:completed_match.start(1)] + new_completed + '\n'
with open(commit_path, 'w') as f:
    f.write(new_content)

print(f'  Archived {len(archive)} commitments to archive/commitments/{year}.md')
print(f'  Kept {len(keep)} recent completed commitments')
"
        fi
    fi
fi

echo ""

# --- 3. List dormant threads ---
echo "--- Dormant Threads ---"

if [ ! -d "$THREADS_DIR" ]; then
    echo "  No threads/ directory found."
else
    DORMANT_FOUND=0
    for THREAD_FILE in "$THREADS_DIR"/*.md; do
        [ -f "$THREAD_FILE" ] || continue
        THREAD_NAME=$(basename "$THREAD_FILE" .md)

        # Find the most recent date in the file
        LATEST_DATE=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$THREAD_FILE" 2>/dev/null | sort -r | head -1)

        if [ -n "$LATEST_DATE" ]; then
            AGE=$(days_between "$LATEST_DATE" "$TODAY")
            if [ "$AGE" -gt 30 ]; then
                DORMANT_FOUND=$((DORMANT_FOUND + 1))
                echo "  💤 $THREAD_NAME — last activity $LATEST_DATE ($AGE days ago)"
            fi
        fi
    done

    if [ "$DORMANT_FOUND" -eq 0 ]; then
        echo "  No dormant threads (all active within 30 days)."
    else
        echo ""
        echo "  $DORMANT_FOUND dormant thread(s) found."
        echo "  Threads are never auto-archived. Review and archive manually if needed."
        echo "  To archive: mv threads/[name].md archive/threads/"
    fi
fi

echo ""
echo "=== Archival complete ==="
