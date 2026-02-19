#!/bin/bash
# snapshot-transcripts.sh - Snapshot Granola transcripts to inbox before they expire
#
# Usage:
#   ./scripts/snapshot-transcripts.sh [brain-root]
#
# Copies new meeting transcripts from Granola cache to inbox/granola/YYYY-MM-DD/
# as individual JSON files. Only copies documents not already snapshotted.
#
# Designed to run frequently (e.g., every 30 min via launchd) as a safety net
# against Granola's ~1 day cache retention.

BRAIN_ROOT="${1:-$HOME/brain}"
INBOX_DIR="$BRAIN_ROOT/inbox/granola"
CACHE_PATH="${GRANOLA_CACHE_PATH:-$HOME/Library/Application Support/Granola/cache-v3.json}"
LOG_PREFIX="[snapshot-transcripts]"

log() {
    echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') $1"
}

if [ ! -f "$CACHE_PATH" ]; then
    log "ERROR: Granola cache not found at $CACHE_PATH"
    exit 1
fi

mkdir -p "$INBOX_DIR"

# Extract and snapshot new meetings
export BRAIN_ROOT="$BRAIN_ROOT"
export INBOX_DIR="$INBOX_DIR"
export CACHE_PATH="$CACHE_PATH"

python3 << 'PYEOF'
import json
import os
import re
import sys
from datetime import datetime

brain_root = os.environ.get("BRAIN_ROOT", os.path.expanduser("~/brain"))
inbox_dir = os.environ.get("INBOX_DIR", os.path.join(brain_root, "inbox", "granola"))
cache_path = os.environ.get("CACHE_PATH", os.path.expanduser("~/Library/Application Support/Granola/cache-v3.json"))

try:
    with open(cache_path, "r") as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError) as e:
    print(f"[snapshot-transcripts] ERROR: Failed to read cache: {e}", file=sys.stderr)
    sys.exit(1)

try:
    cache = json.loads(data["cache"])
    state = cache["state"]
    documents = state.get("documents") or {}
    transcripts = state.get("transcripts") or {}
except (KeyError, json.JSONDecodeError) as e:
    print(f"[snapshot-transcripts] ERROR: Failed to parse cache structure: {e}", file=sys.stderr)
    sys.exit(1)

new_count = 0
skip_count = 0

for doc_id, doc in documents.items():
    created = doc.get("created_at", "")[:10]
    if not created:
        continue

    # Create date directory
    date_dir = os.path.join(inbox_dir, created)
    os.makedirs(date_dir, exist_ok=True)

    # Build a filesystem-safe slug from the title
    cal = doc.get("google_calendar_event") or {}
    title = cal.get("summary", doc.get("title", "untitled"))
    slug = re.sub(r"[^\w\s-]", "", title.lower())
    slug = re.sub(r"[\s]+", "-", slug).strip("-")[:60]
    filename = f"{slug}--{doc_id[:8]}.json"
    filepath = os.path.join(date_dir, filename)

    # Skip if already snapshotted
    if os.path.exists(filepath):
        skip_count += 1
        continue

    # Also check if this doc_id was already saved under a different slug
    existing = [f for f in os.listdir(date_dir) if doc_id[:8] in f]
    if existing:
        skip_count += 1
        continue

    # Extract transcript
    trans = transcripts.get(doc_id) or []
    transcript_text = "\n".join(t.get("text", "") for t in trans)
    word_count = len(transcript_text.split()) if transcript_text.strip() else 0

    # Extract attendees
    attendees = []
    for a in (cal.get("attendees") or []):
        email = a.get("email", "")
        name = a.get("displayName", email.split("@")[0] if email else "")
        if email and not a.get("self"):
            attendees.append({"email": email, "name": name})

    # Extract calendar event timing
    start_obj = cal.get("start") or {}
    end_obj = cal.get("end") or {}

    # Build snapshot
    snapshot = {
        "id": doc_id,
        "title": title,
        "created_at": doc.get("created_at", ""),
        "start": start_obj.get("dateTime", ""),
        "end": end_obj.get("dateTime", ""),
        "attendees": attendees,
        "has_transcript": bool(transcript_text.strip()),
        "word_count": word_count,
        "transcript": transcript_text,
        "snapshotted_at": datetime.now().isoformat(),
    }

    with open(filepath, "w") as f:
        json.dump(snapshot, f, indent=2)

    new_count += 1

now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
print(f"[snapshot-transcripts] {now} Snapshotted {new_count} new meetings, skipped {skip_count} existing")
PYEOF
