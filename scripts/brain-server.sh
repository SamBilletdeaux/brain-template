#!/bin/bash
# brain-server.sh — start, stop, or check the brain web UI
#
# Usage:
#   ./scripts/brain-server.sh start [brain-root]
#   ./scripts/brain-server.sh stop
#   ./scripts/brain-server.sh status

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_DIR="$(dirname "$SCRIPT_DIR")/web"
PID_FILE="/tmp/brain-server.pid"
LOG_FILE="/tmp/brain-server.log"
PORT=3141

case "${1:-status}" in
  start)
    BRAIN_ROOT="${2:-$HOME/brain}"

    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Brain server already running (PID $(cat "$PID_FILE"))"
      echo "http://localhost:$PORT"
      exit 0
    fi

    if [ ! -d "$WEB_DIR/node_modules" ]; then
      echo "Installing dependencies..."
      (cd "$WEB_DIR" && npm install)
    fi

    echo "Starting brain server..."
    node "$WEB_DIR/server.js" --brain "$BRAIN_ROOT" --port "$PORT" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 1

    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Brain server running at http://localhost:$PORT"
      echo "Logs: $LOG_FILE"

      # Open in browser (macOS)
      if command -v open >/dev/null 2>&1; then
        open "http://localhost:$PORT"
      fi
    else
      echo "Failed to start. Check $LOG_FILE"
      rm -f "$PID_FILE"
      exit 1
    fi
    ;;

  stop)
    if [ -f "$PID_FILE" ]; then
      PID=$(cat "$PID_FILE")
      if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "Brain server stopped (PID $PID)"
      else
        echo "Brain server not running (stale PID file)"
      fi
      rm -f "$PID_FILE"
    else
      echo "Brain server not running"
    fi
    ;;

  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Brain server running (PID $(cat "$PID_FILE"))"
      echo "http://localhost:$PORT"
    else
      echo "Brain server not running"
      rm -f "$PID_FILE" 2>/dev/null
    fi
    ;;

  *)
    echo "Usage: brain-server.sh {start|stop|status} [brain-root]"
    exit 1
    ;;
esac
