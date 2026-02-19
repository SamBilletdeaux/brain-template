#!/bin/bash
# validate-config.sh - Validate brain config.md structure and paths
#
# Usage:
#   ./scripts/validate-config.sh [brain-root]
#
# Exit codes:
#   0 - Config valid
#   1 - Config has errors (printed to stderr)
#   2 - Config file not found
#
# Checks:
#   - config.md exists and has required fields (Name, Role)
#   - At least one data source is configured
#   - Referenced paths exist (brain root, archive, cache paths)
#   - Data source types are recognized

BRAIN_ROOT="${1:-$(grep -A1 '## Paths' "${1:-$HOME/brain}/config.md" 2>/dev/null | grep 'Brain root' | sed 's/.*: *//' | sed "s|~/|$HOME/|")}"
BRAIN_ROOT="${BRAIN_ROOT:-$HOME/brain}"
CONFIG_FILE="$BRAIN_ROOT/config.md"
ERRORS=0

error() {
    echo "ERROR: $1" >&2
    ERRORS=$((ERRORS + 1))
}

warn() {
    echo "WARN:  $1" >&2
}

info() {
    echo "OK:    $1"
}

# Check config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: config.md not found at $CONFIG_FILE" >&2
    exit 2
fi

# Check required identity fields
NAME=$(grep '\*\*Name\*\*' "$CONFIG_FILE" | sed 's/.*\*\*: *//')
ROLE=$(grep '\*\*Role\*\*' "$CONFIG_FILE" | sed 's/.*\*\*: *//')

if [ -z "$NAME" ] || echo "$NAME" | grep -q "run /setup"; then
    error "Name not configured (run /setup)"
else
    info "Name: $NAME"
fi

if [ -z "$ROLE" ] || echo "$ROLE" | grep -q "run /setup"; then
    error "Role not configured (run /setup)"
else
    info "Role: $ROLE"
fi

# Check for at least one data source
# Look for ### headings under ## Data Sources, excluding HTML comment blocks
SOURCE_COUNT=$(awk '/^## Data Sources/,/^## [^D]/' "$CONFIG_FILE" | awk '/^<!--/,/-->/{next} /^### /{count++} END{print count+0}')
if [ "$SOURCE_COUNT" -eq 0 ]; then
    error "No data sources configured (run /setup to add one)"
else
    info "Data sources: $SOURCE_COUNT configured"
fi

# Check recognized data source types
KNOWN_TYPES="granola otter file-drop fireflies"
awk '/^## Data Sources/,/^## [^D]/' "$CONFIG_FILE" | grep '\*\*Type\*\*' | sed 's/.*\*\*: *//' | while read -r TYPE; do
    TYPE=$(echo "$TYPE" | xargs)
    if ! echo "$KNOWN_TYPES" | grep -qw "$TYPE"; then
        # Can't increment ERRORS from subshell, so just warn
        echo "WARN:  Unknown data source type: '$TYPE' (known: $KNOWN_TYPES)" >&2
    fi
done

# Check Granola cache path if granola source configured
GRANOLA_PATH=$(awk '/^## Data Sources/,/^## [^D]/' "$CONFIG_FILE" | awk '/^<!--/,/-->/{next} {print}' | grep -A5 'granola' | grep 'Cache path' | sed 's/.*\*\*: *//' | sed "s|~/|$HOME/|")
if [ -n "$GRANOLA_PATH" ]; then
    if [ -f "$GRANOLA_PATH" ]; then
        info "Granola cache found at $GRANOLA_PATH"
    else
        error "Granola cache not found at $GRANOLA_PATH"
    fi
fi

# Check required directories exist
for DIR in threads people archive; do
    if [ -d "$BRAIN_ROOT/$DIR" ]; then
        info "Directory exists: $DIR/"
    else
        warn "Directory missing: $BRAIN_ROOT/$DIR/ (will be created on first use)"
    fi
done

# Check required files exist
for FILE in preferences.md commitments.md handoff.md health.md; do
    if [ -f "$BRAIN_ROOT/$FILE" ]; then
        info "File exists: $FILE"
    else
        error "Required file missing: $BRAIN_ROOT/$FILE"
    fi
done

# Summary
echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "Config validation failed with $ERRORS error(s)." >&2
    exit 1
else
    echo "Config validation passed."
    exit 0
fi
