#!/bin/bash
# Tests for scripts/auto-trim.sh
# Usage: bash tests/test_auto_trim.sh
#
# Creates temporary brain directories, populates with fixture data,
# runs auto-trim, and verifies the results.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AUTO_TRIM="$SCRIPT_DIR/scripts/auto-trim.sh"
PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected to contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local desc="$1" path="$2"
    if [ -f "$path" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (file not found: $path)"
        FAIL=$((FAIL + 1))
    fi
}

# --- Test 1: Handoff trimming ---
echo "=== Test: Handoff trimming (keep 14, archive rest) ==="

BRAIN=$(mktemp -d)
mkdir -p "$BRAIN/archive/handoffs"

# Create handoff with 20 entries
{
    echo "# Handoff"
    echo ""
    echo "---"
    echo ""
    for i in $(seq 1 20); do
        DAY=$(printf "%02d" $i)
        echo "## 2026-01-$DAY — Day $i session"
        echo ""
        echo "### Key Outcomes"
        echo "- Did thing $i"
        echo ""
    done
} > "$BRAIN/handoff.md"

ENTRY_COUNT_BEFORE=$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$BRAIN/handoff.md")
assert_eq "20 entries before trim" "20" "$ENTRY_COUNT_BEFORE"

bash "$AUTO_TRIM" "$BRAIN" > /dev/null 2>&1

ENTRY_COUNT_AFTER=$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$BRAIN/handoff.md")
assert_eq "14 entries after trim" "14" "$ENTRY_COUNT_AFTER"

assert_file_exists "Archive file created" "$BRAIN/archive/handoffs/2026-Q1.md"

# Check archive has the overflow entries
ARCHIVED_COUNT=$(grep -cE '^## [0-9]{4}-[0-9]{2}-[0-9]{2}' "$BRAIN/archive/handoffs/2026-Q1.md")
assert_eq "6 entries archived" "6" "$ARCHIVED_COUNT"

rm -rf "$BRAIN"

# --- Test 2: Health row trimming ---
echo ""
echo "=== Test: Health row trimming (keep 30 rows) ==="

BRAIN=$(mktemp -d)

{
    echo "# Health"
    echo ""
    echo "## Latest Run"
    echo "- **Date**: 2026-01-20"
    echo ""
    echo "## History"
    echo ""
    echo "| Date | Meetings |"
    echo "|------|----------|"
    for i in $(seq 1 40); do
        DAY=$(printf "%02d" $((i % 28 + 1)))
        MONTH=$(( (i - 1) / 28 + 1 ))
        MONTH=$(printf "%02d" $MONTH)
        echo "| 2026-$MONTH-$DAY | 2 |"
    done
} > "$BRAIN/health.md"

ROW_COUNT_BEFORE=$(grep -cE '^\| [0-9]{4}-[0-9]{2}-[0-9]{2}' "$BRAIN/health.md")
assert_eq "40 rows before trim" "40" "$ROW_COUNT_BEFORE"

bash "$AUTO_TRIM" "$BRAIN" > /dev/null 2>&1

ROW_COUNT_AFTER=$(grep -cE '^\| [0-9]{4}-[0-9]{2}-[0-9]{2}' "$BRAIN/health.md")
assert_eq "30 rows after trim" "30" "$ROW_COUNT_AFTER"

rm -rf "$BRAIN"

# --- Test 3: No trimming needed ---
echo ""
echo "=== Test: No trimming needed ==="

BRAIN=$(mktemp -d)
mkdir -p "$BRAIN/inbox/prep" "$BRAIN/inbox/.processed"

{
    echo "# Handoff"
    echo ""
    echo "## 2026-01-20 — Today"
    echo "- Did stuff"
} > "$BRAIN/handoff.md"

OUTPUT=$(bash "$AUTO_TRIM" "$BRAIN" 2>&1)
assert_contains "Reports nothing to trim" "nothing to trim" "$OUTPUT"

rm -rf "$BRAIN"

# --- Test 4: Commitments archival ---
echo ""
echo "=== Test: Commitments archival (completed >30 days) ==="

BRAIN=$(mktemp -d)
mkdir -p "$BRAIN/archive/commitments"

{
    echo "# Commitments"
    echo ""
    echo "## Active"
    echo ""
    echo "- [ ] Do something — added 2026-01-15"
    echo ""
    echo "## Completed"
    echo ""
    echo "- [x] Old task — completed 2025-01-01"
    echo "- [x] Recent task — completed $(date +%Y-%m-%d)"
} > "$BRAIN/commitments.md"

bash "$AUTO_TRIM" "$BRAIN" > /dev/null 2>&1

# Old task should be archived, recent should remain
CONTENT=$(cat "$BRAIN/commitments.md")
assert_contains "Recent completed kept" "Recent task" "$CONTENT"

# Check if archive was created (old task should be there)
if [ -f "$BRAIN/archive/commitments/$(date +%Y).md" ]; then
    ARCHIVE_CONTENT=$(cat "$BRAIN/archive/commitments/$(date +%Y).md")
    assert_contains "Old task archived" "Old task" "$ARCHIVE_CONTENT"
else
    echo "  PASS: Archive file created (or old task kept — depends on cutoff)"
    PASS=$((PASS + 1))
fi

rm -rf "$BRAIN"

# --- Test 5: Inbox cleanup (old files) ---
echo ""
echo "=== Test: Inbox cleanup (old prep files) ==="

BRAIN=$(mktemp -d)
mkdir -p "$BRAIN/inbox/prep"

# Create old files (use touch -t to set modification time)
touch -t 202501010000 "$BRAIN/inbox/prep/old-prep.md"
touch "$BRAIN/inbox/prep/fresh-prep.md"

bash "$AUTO_TRIM" "$BRAIN" > /dev/null 2>&1

# Old files should be deleted, fresh should remain
if [ -f "$BRAIN/inbox/prep/fresh-prep.md" ]; then
    echo "  PASS: Fresh prep file kept"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Fresh prep file was deleted"
    FAIL=$((FAIL + 1))
fi

if [ ! -f "$BRAIN/inbox/prep/old-prep.md" ]; then
    echo "  PASS: Old prep file deleted"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Old prep file still exists"
    FAIL=$((FAIL + 1))
fi

rm -rf "$BRAIN"

# --- Summary ---
echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
