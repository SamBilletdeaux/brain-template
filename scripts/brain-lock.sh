#!/usr/bin/env bash
# brain-lock.sh — Session lockfile management
#
# Usage:
#   ./scripts/brain-lock.sh acquire [brain-root] [session-name]
#   ./scripts/brain-lock.sh release [brain-root]
#   ./scripts/brain-lock.sh check   [brain-root]
#   ./scripts/brain-lock.sh force-release [brain-root]
#
# Exit codes:
#   acquire: 0 = acquired, 1 = held by another process
#   release: 0 = released, 1 = no lock to release
#   check:   0 = unlocked, 1 = locked (prints holder info)
#   force-release: 0 = released

set -euo pipefail

COMMAND="${1:-check}"
BRAIN_ROOT="${2:-$HOME/brain}"
SESSION="${3:-unknown}"
LOCK_FILE="$BRAIN_ROOT/.brain.lock"

is_pid_alive() {
  kill -0 "$1" 2>/dev/null
}

case "$COMMAND" in
  acquire)
    # Check for existing lock
    if [ -f "$LOCK_FILE" ]; then
      LOCK_PID=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['pid'])" "$LOCK_FILE" 2>/dev/null || echo "")
      LOCK_SESSION=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['session'])" "$LOCK_FILE" 2>/dev/null || echo "unknown")
      LOCK_TIME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['started_at'])" "$LOCK_FILE" 2>/dev/null || echo "unknown")

      if [ -n "$LOCK_PID" ] && is_pid_alive "$LOCK_PID"; then
        echo "Lock held by PID $LOCK_PID ($LOCK_SESSION since $LOCK_TIME)"
        exit 1
      else
        echo "Stale lock detected (PID $LOCK_PID no longer running). Reclaiming."
        rm -f "$LOCK_FILE"
      fi
    fi

    # Acquire lock
    python3 -c "
import json, os, datetime
lock = {
    'pid': os.getppid(),
    'session': '$SESSION',
    'started_at': datetime.datetime.now().isoformat()
}
with open('$LOCK_FILE', 'w') as f:
    json.dump(lock, f)
"
    echo "Lock acquired ($$SESSION)"
    ;;

  release)
    if [ -f "$LOCK_FILE" ]; then
      rm -f "$LOCK_FILE"
      echo "Lock released"
    else
      echo "No lock to release"
      exit 1
    fi
    ;;

  check)
    if [ ! -f "$LOCK_FILE" ]; then
      echo "Unlocked"
      exit 0
    fi

    LOCK_PID=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['pid'])" "$LOCK_FILE" 2>/dev/null || echo "")
    LOCK_SESSION=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['session'])" "$LOCK_FILE" 2>/dev/null || echo "unknown")
    LOCK_TIME=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['started_at'])" "$LOCK_FILE" 2>/dev/null || echo "unknown")

    if [ -n "$LOCK_PID" ] && is_pid_alive "$LOCK_PID"; then
      echo "Locked by PID $LOCK_PID ($LOCK_SESSION since $LOCK_TIME)"
      exit 1
    else
      echo "Stale lock (PID $LOCK_PID no longer running)"
      exit 1
    fi
    ;;

  force-release)
    rm -f "$LOCK_FILE"
    echo "Lock force-released"
    ;;

  *)
    echo "Usage: brain-lock.sh {acquire|release|check|force-release} [brain-root] [session-name]"
    exit 1
    ;;
esac
