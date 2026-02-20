#!/usr/bin/env bash
# Tests for check-preferences.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/scripts/check-preferences.sh"
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
  if echo "$output" | grep -qiE "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected output to contain '$pattern')"
    FAIL=$((FAIL + 1))
  fi
}

# --- Test: Contradictory rules ---
echo "=== Test: Contradictory rules ==="
mkdir -p "$TMPDIR/test1"
cat > "$TMPDIR/test1/preferences.md" << 'EOF'
# Preferences

## Tracking Rules
- Always track scheduling items
- Don't track scheduling items
EOF
OUTPUT=$("$CHECK_SCRIPT" "$TMPDIR/test1" 2>&1 || true)
EXIT_CODE=0
"$CHECK_SCRIPT" "$TMPDIR/test1" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit 1 "$EXIT_CODE" "Exits with 1 on contradiction"
assert_contains "$OUTPUT" "CONFLICT" "Reports conflict"

# --- Test: Near-duplicate rules ---
echo ""
echo "=== Test: Near-duplicate rules ==="
mkdir -p "$TMPDIR/test2"
cat > "$TMPDIR/test2/preferences.md" << 'EOF'
# Preferences

## Tracking Rules
- Don't track social coordination items like scheduling coffee
- Don't track social coordination items such as scheduling coffee chats
EOF
OUTPUT=$("$CHECK_SCRIPT" "$TMPDIR/test2" 2>&1 || true)
EXIT_CODE=0
"$CHECK_SCRIPT" "$TMPDIR/test2" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit 1 "$EXIT_CODE" "Exits with 1 on near-duplicate"
assert_contains "$OUTPUT" "NEAR-DUPLICATE|CONFLICT" "Reports duplicate or conflict"

# --- Test: Too many rules (>25) ---
echo ""
echo "=== Test: Size warning (>25 rules) ==="
mkdir -p "$TMPDIR/test3"
{
  echo "# Preferences"
  echo ""
  echo "## Rules"
  for i in $(seq 1 30); do
    echo "- Rule number $i about unique topic area $i xyz$i"
  done
} > "$TMPDIR/test3/preferences.md"
OUTPUT=$("$CHECK_SCRIPT" "$TMPDIR/test3" 2>&1 || true)
EXIT_CODE=0
"$CHECK_SCRIPT" "$TMPDIR/test3" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit 1 "$EXIT_CODE" "Exits with 1 on >25 rules"
assert_contains "$OUTPUT" "SIZE|30 rules" "Reports size warning"

# --- Test: Clean file ---
echo ""
echo "=== Test: Clean preferences file ==="
mkdir -p "$TMPDIR/test4"
cat > "$TMPDIR/test4/preferences.md" << 'EOF'
# Preferences

## Tracking Rules
- Don't track social items
- Track meaningful deliverables with deadlines

## Sensitivity Rules
- Never document negative performance assessments
EOF
EXIT_CODE=0
"$CHECK_SCRIPT" "$TMPDIR/test4" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "Exits with 0 on clean file"

echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="
[ "$FAIL" -eq 0 ] || exit 1
