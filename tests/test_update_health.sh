#!/bin/bash
# Tests for scripts/update-health.sh
# Usage: bash tests/test_update_health.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE_HEALTH="$SCRIPT_DIR/scripts/update-health.sh"
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
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected to contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (should NOT contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

create_health_file() {
    local BRAIN="$1"
    mkdir -p "$BRAIN/threads" "$BRAIN/people"
    cat > "$BRAIN/health.md" << 'HEALTH'
# System Health

## Latest Run
<!-- Updated automatically by /wind-down Phase 6 -->

- **Date**: (not yet run)
- **Meetings processed**: 0
- **Transcript volume**: 0 words
- **Processing mode**: full
- **Decisions made**: 0 (🟢: 0, 🟡: 0, 🔴: 0)
- **Corrections received**: 0
- **New preferences rules added**: 0
- **Active threads**: 0
- **Dormant threads**: 0
- **People files**: 0
- **Preferences rule count**: 0
- **Days since last wind-down**: N/A
- **Consecutive days run**: 0

## History

| Date | Meetings | Words | Mode | Decisions | Corrections | Threads | People | Rules |
|------|----------|-------|------|-----------|-------------|---------|--------|-------|
| (no entries yet) | | | | | | | | |
HEALTH

    # Create preferences.md for rule counting
    cat > "$BRAIN/preferences.md" << 'PREFS'
# Preferences
- Rule one
- Rule two
- Rule three
PREFS
}

# --- Test 1: First run adds entry ---
echo "=== Test: First run adds new entry ==="

BRAIN=$(mktemp -d)
create_health_file "$BRAIN"

# Add some thread and people files
touch "$BRAIN/threads/thread-a.md" "$BRAIN/threads/thread-b.md"
touch "$BRAIN/people/alice.md"

bash "$UPDATE_HEALTH" "$BRAIN" date=2026-01-20 meetings=3 words=5000 mode=full \
    decisions_green=4 decisions_yellow=2 decisions_red=1 corrections=1 new_rules=1

CONTENT=$(cat "$BRAIN/health.md")
assert_contains "Date updated" "2026-01-20" "$CONTENT"
assert_contains "Meetings updated" "3" "$CONTENT"
assert_contains "Words updated" "5000" "$CONTENT"
assert_not_contains "Placeholder row removed" "no entries yet" "$CONTENT"

# Check history row was added
ROW_COUNT=$(grep -cE '^\| 2026-01-20' "$BRAIN/health.md")
assert_eq "History row added" "1" "$ROW_COUNT"

rm -rf "$BRAIN"

# --- Test 2: Idempotent update ---
echo ""
echo "=== Test: Idempotent update (same date updates, not duplicates) ==="

BRAIN=$(mktemp -d)
create_health_file "$BRAIN"
touch "$BRAIN/threads/thread-a.md"
touch "$BRAIN/people/alice.md"

# First run
bash "$UPDATE_HEALTH" "$BRAIN" date=2026-01-20 meetings=2 words=3000

# Second run same date, different data
bash "$UPDATE_HEALTH" "$BRAIN" date=2026-01-20 meetings=5 words=8000

# Should have exactly 1 row for this date
ROW_COUNT=$(grep -cE '^\| 2026-01-20' "$BRAIN/health.md")
assert_eq "Only one row for same date" "1" "$ROW_COUNT"

# Should have updated values
CONTENT=$(cat "$BRAIN/health.md")
assert_contains "Updated meeting count" "5" "$CONTENT"

rm -rf "$BRAIN"

# --- Test 3: Auto-counts threads and people ---
echo ""
echo "=== Test: Auto-counts threads and people files ==="

BRAIN=$(mktemp -d)
create_health_file "$BRAIN"
touch "$BRAIN/threads/a.md" "$BRAIN/threads/b.md" "$BRAIN/threads/c.md"
touch "$BRAIN/people/alice.md" "$BRAIN/people/bob.md"

bash "$UPDATE_HEALTH" "$BRAIN" date=2026-01-20

CONTENT=$(cat "$BRAIN/health.md")
assert_contains "Thread count" "Active threads**: 3" "$CONTENT"
assert_contains "People count" "People files**: 2" "$CONTENT"

rm -rf "$BRAIN"

# --- Test 4: Counts preference rules ---
echo ""
echo "=== Test: Counts preference rules ==="

BRAIN=$(mktemp -d)
create_health_file "$BRAIN"

bash "$UPDATE_HEALTH" "$BRAIN" date=2026-01-20

CONTENT=$(cat "$BRAIN/health.md")
assert_contains "Preference rule count" "rule count**: 3" "$CONTENT"

rm -rf "$BRAIN"

# --- Summary ---
echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
