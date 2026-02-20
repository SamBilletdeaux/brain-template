#!/bin/bash
# install-hooks.sh - Install git hooks for automatic brain indexing
#
# Usage:
#   ./scripts/install-hooks.sh [brain-root] [scripts-dir]
#
# Installs a post-commit hook in the brain repo that re-indexes
# changed files after every git commit. This keeps the search
# index in sync with your markdown files automatically.

BRAIN_ROOT="${1:-$HOME/brain}"
SCRIPTS_DIR="${2:-$(cd "$(dirname "$0")" && pwd)}"
HOOKS_DIR="$BRAIN_ROOT/.git/hooks"

if [ ! -d "$BRAIN_ROOT/.git" ]; then
    echo "Error: $BRAIN_ROOT is not a git repository" >&2
    exit 1
fi

mkdir -p "$HOOKS_DIR"

# Write post-commit hook
cat > "$HOOKS_DIR/post-commit" << HOOK
#!/bin/bash
# Auto-index brain after each commit
# Installed by brain-template/scripts/install-hooks.sh

SCRIPTS_DIR="$SCRIPTS_DIR"
BRAIN_ROOT="$BRAIN_ROOT"

# Run indexer in background so commits aren't slowed down
(python3 "\$SCRIPTS_DIR/indexer.py" "\$BRAIN_ROOT" > /dev/null 2>&1) &

# Run data validation in background, log warnings
(bash "\$SCRIPTS_DIR/validate-data.sh" "\$BRAIN_ROOT" > /tmp/brain-validate.log 2>&1) &
HOOK

chmod +x "$HOOKS_DIR/post-commit"

echo "Git hook installed."
echo "  Hook: $HOOKS_DIR/post-commit"
echo "  Action: Re-indexes brain after every commit (runs in background)"
echo ""
echo "The search index will now stay in sync automatically."
