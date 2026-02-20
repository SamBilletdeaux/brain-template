#!/usr/bin/env bash
# Tests for brain-lock.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_SCRIPT="$SCRIPT_DIR/scripts/brain-lock.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

assert_exit() {
  local expected="$1" actual="$2" desc="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local output="$1" pattern="$2" desc="$3"
  if echo "$output" | grep -qi "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected output to contain '$pattern')"
    FAIL=$((FAIL + 1))
  fi
}

# --- Test: Acquire and release ---
echo "=== Test: Acquire and release ==="
EXIT_CODE=0
"$LOCK_SCRIPT" acquire "$TMPDIR" "test-session" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "Acquire succeeds"

[ -f "$TMPDIR/.brain.lock" ]
assert_exit 0 $? "Lock file created"

EXIT_CODE=0
"$LOCK_SCRIPT" release "$TMPDIR" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "Release succeeds"

[ ! -f "$TMPDIR/.brain.lock" ]
assert_exit 0 $? "Lock file removed"

# --- Test: Check unlocked ---
echo ""
echo "=== Test: Check unlocked ==="
EXIT_CODE=0
OUTPUT=$("$LOCK_SCRIPT" check "$TMPDIR" 2>&1) || EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "Check returns 0 when unlocked"
assert_contains "$OUTPUT" "unlocked" "Reports unlocked"

# --- Test: Stale lock detection ---
echo ""
echo "=== Test: Stale lock detection ==="
# Create a lock with a PID that doesn't exist
cat > "$TMPDIR/.brain.lock" << 'EOF'
{"pid": 99999999, "session": "stale-session", "started_at": "2026-01-01T00:00:00"}
EOF

EXIT_CODE=0
OUTPUT=$("$LOCK_SCRIPT" acquire "$TMPDIR" "new-session" 2>&1) || EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "Acquire reclaims stale lock"
assert_contains "$OUTPUT" "stale\|reclaim" "Reports stale lock"

# Clean up
"$LOCK_SCRIPT" release "$TMPDIR" > /dev/null 2>&1

# --- Test: Force release ---
echo ""
echo "=== Test: Force release ==="
cat > "$TMPDIR/.brain.lock" << 'EOF'
{"pid": 1, "session": "force-test", "started_at": "2026-01-01T00:00:00"}
EOF

EXIT_CODE=0
"$LOCK_SCRIPT" force-release "$TMPDIR" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "Force-release succeeds"

[ ! -f "$TMPDIR/.brain.lock" ]
assert_exit 0 $? "Lock file removed after force-release"

echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="
[ "$FAIL" -eq 0 ] || exit 1
