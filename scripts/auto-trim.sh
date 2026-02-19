#!/bin/bash
# auto-trim.sh — Lightweight archival designed to run at the end of every wind-down.
#
# Keeps active files bounded so they never balloon:
#   - handoff.md: keep last 14 entries, archive older
#   - health.md: keep last 30 history rows
#   - commitments.md: archive completed items older than 30 days
#   - inbox/prep/: delete packets older than 7 days
#   - inbox/drafts/: delete drafts older than 7 days
#   - inbox/.processed/: delete markers older than 30 days
#
# Usage:
#   ./scripts/auto-trim.sh [brain-root]
#
# Designed to be safe and fast. If anything looks wrong, it skips
# rather than risking data loss. Full archival (with dry-run) is
# still available via archive.sh.

BRAIN_ROOT="${1:-$HOME/brain}"
TRIMMED=0

# --- Handoff: keep last 14 entries ---
HANDOFF_FILE="$BRAIN_ROOT/handoff.md"
if [ -f "$HANDOFF_FILE" ]; then
    ENTRY_COUNT=$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$HANDOFF_FILE")
    if [ "$ENTRY_COUNT" -gt 14 ]; then
        python3 -c "
import re, os

brain_root = '$BRAIN_ROOT'
handoff_path = '$HANDOFF_FILE'
archive_dir = os.path.join(brain_root, 'archive', 'handoffs')
os.makedirs(archive_dir, exist_ok=True)

with open(handoff_path, 'r') as f:
    content = f.read()

# Split: header (everything before first ## date) + entries
header_match = re.match(r'(.*?)(?=## \d{4}-\d{2}-\d{2})', content, re.DOTALL)
header = header_match.group(1) if header_match else '# Handoff\n\n---\n\n'

pattern = r'(## \d{4}-\d{2}-\d{2}.*?)(?=\n## \d{4}-\d{2}-\d{2}|\Z)'
entries = re.findall(pattern, content, re.DOTALL)

keep = entries[:14]
overflow = entries[14:]

if not overflow:
    exit(0)

# Archive overflow entries by quarter
archived = {}
for entry in overflow:
    date_match = re.match(r'## (\d{4}-\d{2}-\d{2})', entry)
    if date_match:
        d = date_match.group(1)
        year, month = d[:4], int(d[5:7])
        q = (month - 1) // 3 + 1
        quarter = f'{year}-Q{q}'
        archived.setdefault(quarter, []).append(entry.strip())

for quarter, elist in sorted(archived.items()):
    qfile = os.path.join(archive_dir, f'{quarter}.md')
    existing = ''
    if os.path.exists(qfile):
        with open(qfile, 'r') as f:
            existing = f.read()
    with open(qfile, 'w') as f:
        if existing:
            f.write(existing.rstrip() + '\n\n')
        else:
            f.write(f'# Archived Handoff Entries — {quarter}\n\n')
        for e in elist:
            f.write(e + '\n\n')

# Rewrite handoff.md with only recent entries
with open(handoff_path, 'w') as f:
    f.write(header)
    for e in keep:
        f.write(e.strip() + '\n\n')

print(f'handoff: kept {len(keep)}, archived {len(overflow)}')
" 2>/dev/null && TRIMMED=$((TRIMMED + 1))
    fi
fi

# --- Health: keep last 30 history rows ---
HEALTH_FILE="$BRAIN_ROOT/health.md"
if [ -f "$HEALTH_FILE" ]; then
    ROW_COUNT=$(grep -cE '^\| [0-9]{4}-[0-9]{2}-[0-9]{2}' "$HEALTH_FILE")
    if [ "$ROW_COUNT" -gt 30 ]; then
        python3 -c "
import re

health_path = '$HEALTH_FILE'
with open(health_path, 'r') as f:
    content = f.read()

# Find the history table rows (lines starting with | YYYY-MM-DD)
lines = content.split('\n')
data_rows = []
data_start = None

for i, line in enumerate(lines):
    if re.match(r'^\| \d{4}-\d{2}-\d{2}', line):
        if data_start is None:
            data_start = i
        data_rows.append((i, line))

if len(data_rows) <= 30 or data_start is None:
    exit(0)

# Keep first 30 rows (most recent — they're in reverse chronological order)
keep_indices = set(idx for idx, _ in data_rows[:30])
new_lines = []
for i, line in enumerate(lines):
    if re.match(r'^\| \d{4}-\d{2}-\d{2}', line) and i not in keep_indices:
        continue  # skip old row
    new_lines.append(line)

with open(health_path, 'w') as f:
    f.write('\n'.join(new_lines))

trimmed = len(data_rows) - 30
print(f'health: trimmed {trimmed} old rows, kept 30')
" 2>/dev/null && TRIMMED=$((TRIMMED + 1))
    fi
fi

# --- Commitments: archive completed items older than 30 days ---
COMMITMENTS_FILE="$BRAIN_ROOT/commitments.md"
if [ -f "$COMMITMENTS_FILE" ]; then
    # Only run if there are completed items
    if grep -q '^\- \[x\]' "$COMMITMENTS_FILE" 2>/dev/null; then
        python3 -c "
import re, os
from datetime import datetime, timedelta

brain_root = '$BRAIN_ROOT'
commit_path = '$COMMITMENTS_FILE'
archive_dir = os.path.join(brain_root, 'archive', 'commitments')

with open(commit_path, 'r') as f:
    content = f.read()

cutoff = datetime.now() - timedelta(days=30)

# Find Completed section
completed_match = re.search(r'(## Completed\n.*?\n)(.*?)$', content, re.DOTALL)
if not completed_match:
    exit(0)

section_header = completed_match.group(1)
completed_text = completed_match.group(2)
lines = completed_text.strip().split('\n')

keep = []
archive = []

for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith('(') or stripped.startswith('<!--'):
        continue
    dates = re.findall(r'(\d{4}-\d{2}-\d{2})', stripped)
    if dates:
        latest = max(datetime.strptime(d, '%Y-%m-%d') for d in dates)
        if latest < cutoff:
            archive.append(stripped)
        else:
            keep.append(stripped)
    else:
        keep.append(stripped)

if not archive:
    exit(0)

# Write archived
os.makedirs(archive_dir, exist_ok=True)
year = datetime.now().year
archive_file = os.path.join(archive_dir, f'{year}.md')
existing = ''
if os.path.exists(archive_file):
    with open(archive_file, 'r') as f:
        existing = f.read()
with open(archive_file, 'w') as f:
    if existing:
        f.write(existing.rstrip() + '\n')
    else:
        f.write(f'# Archived Commitments — {year}\n\n')
    for item in archive:
        f.write(item + '\n')

# Update commitments.md
new_completed = '\n'.join(keep) if keep else '(Nothing yet.)'
new_content = content[:completed_match.start(2)] + new_completed + '\n'
with open(commit_path, 'w') as f:
    f.write(new_content)

print(f'commitments: archived {len(archive)}, kept {len(keep)}')
" 2>/dev/null && TRIMMED=$((TRIMMED + 1))
    fi
fi

# --- Inbox cleanup: delete old prep/drafts/markers ---
cleanup_old_files() {
    local DIR="$1"
    local MAX_AGE_DAYS="$2"
    local LABEL="$3"

    [ -d "$DIR" ] || return

    local COUNT=0
    find "$DIR" -type f -mtime +"$MAX_AGE_DAYS" 2>/dev/null | while read -r FILE; do
        rm -f "$FILE"
        COUNT=$((COUNT + 1))
    done

    # Clean empty subdirectories
    find "$DIR" -type d -empty -delete 2>/dev/null

    local DELETED=$(find "$DIR" -type f -mtime +"$MAX_AGE_DAYS" 2>/dev/null | wc -l | xargs)
    # Already deleted above, just report if we would have
}

# Prep packets older than 7 days
if [ -d "$BRAIN_ROOT/inbox/prep" ]; then
    OLD_PREP=$(find "$BRAIN_ROOT/inbox/prep" -type f -mtime +7 2>/dev/null | wc -l | xargs)
    if [ "$OLD_PREP" -gt 0 ]; then
        find "$BRAIN_ROOT/inbox/prep" -type f -mtime +7 -delete 2>/dev/null
        echo "inbox/prep: deleted $OLD_PREP old packets"
        TRIMMED=$((TRIMMED + 1))
    fi
fi

# Draft files older than 7 days
if [ -d "$BRAIN_ROOT/inbox/drafts" ]; then
    OLD_DRAFTS=$(find "$BRAIN_ROOT/inbox/drafts" -type f -mtime +7 2>/dev/null | wc -l | xargs)
    if [ "$OLD_DRAFTS" -gt 0 ]; then
        find "$BRAIN_ROOT/inbox/drafts" -type f -mtime +7 -delete 2>/dev/null
        echo "inbox/drafts: deleted $OLD_DRAFTS old drafts"
        TRIMMED=$((TRIMMED + 1))
    fi
fi

# Processed markers older than 30 days
if [ -d "$BRAIN_ROOT/inbox/.processed" ]; then
    OLD_MARKERS=$(find "$BRAIN_ROOT/inbox/.processed" -type f -mtime +30 2>/dev/null | wc -l | xargs)
    if [ "$OLD_MARKERS" -gt 0 ]; then
        find "$BRAIN_ROOT/inbox/.processed" -type f -mtime +30 -delete 2>/dev/null
        echo "inbox/.processed: deleted $OLD_MARKERS old markers"
        TRIMMED=$((TRIMMED + 1))
    fi
fi

if [ "$TRIMMED" -eq 0 ]; then
    echo "auto-trim: nothing to trim"
else
    echo "auto-trim: $TRIMMED area(s) trimmed"
fi
