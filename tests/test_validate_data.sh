#!/usr/bin/env bash
# Tests for validate-data.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/scripts/validate-data.sh"
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

# --- Test: Broken wiki-links ---
echo "=== Test: Broken wiki-links ==="
mkdir -p "$TMPDIR/test1/threads" "$TMPDIR/test1/people"
echo -e "# Test Thread\n\nSee [[nonexistent-thing]] for details." > "$TMPDIR/test1/threads/my-thread.md"
EXIT_CODE=0
OUTPUT=$("$VALIDATE_SCRIPT" "$TMPDIR/test1" 2>&1) || EXIT_CODE=$?
assert_exit 1 "$EXIT_CODE" "Warns on broken link"
assert_contains "$OUTPUT" "broken\|nonexistent" "Reports broken link"

# --- Test: Empty files ---
echo ""
echo "=== Test: Empty thread files ==="
mkdir -p "$TMPDIR/test2/threads" "$TMPDIR/test2/people"
touch "$TMPDIR/test2/threads/empty-thread.md"
EXIT_CODE=0
OUTPUT=$("$VALIDATE_SCRIPT" "$TMPDIR/test2" 2>&1) || EXIT_CODE=$?
assert_exit 2 "$EXIT_CODE" "Errors on empty file"
assert_contains "$OUTPUT" "empty" "Reports empty file"

# --- Test: Handoff date ordering ---
echo ""
echo "=== Test: Handoff date ordering ==="
mkdir -p "$TMPDIR/test3"
cat > "$TMPDIR/test3/handoff.md" << 'EOF'
# Handoff

## 2026-02-10
Older entry first (wrong order)

## 2026-02-15
Newer entry second (should be first)
EOF
EXIT_CODE=0
OUTPUT=$("$VALIDATE_SCRIPT" "$TMPDIR/test3" 2>&1) || EXIT_CODE=$?
assert_exit 2 "$EXIT_CODE" "Errors on out-of-order handoff dates"
assert_contains "$OUTPUT" "order" "Reports date ordering issue"

# --- Test: Clean brain ---
echo ""
echo "=== Test: Clean brain ==="
mkdir -p "$TMPDIR/test4/threads" "$TMPDIR/test4/people"
echo "# Good Thread" > "$TMPDIR/test4/threads/good-thread.md"
echo "# Good Person" > "$TMPDIR/test4/people/good-person.md"
cat > "$TMPDIR/test4/handoff.md" << 'EOF'
# Handoff

## 2026-02-15
Newer entry

## 2026-02-10
Older entry
EOF
EXIT_CODE=0
"$VALIDATE_SCRIPT" "$TMPDIR/test4" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "Clean brain passes"

# --- Test: Duplicate commitments ---
echo ""
echo "=== Test: Duplicate commitments ==="
mkdir -p "$TMPDIR/test5"
cat > "$TMPDIR/test5/commitments.md" << 'EOF'
# Commitments

## Active
- [ ] Send report to Wei — added 2026-02-10
- [ ] Send report to Wei — added 2026-02-10
EOF
EXIT_CODE=0
OUTPUT=$("$VALIDATE_SCRIPT" "$TMPDIR/test5" 2>&1) || EXIT_CODE=$?
assert_exit 1 "$EXIT_CODE" "Warns on duplicate commitment"
assert_contains "$OUTPUT" "duplicate\|Duplicate" "Reports duplicate"

echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="
[ "$FAIL" -eq 0 ] || exit 1
