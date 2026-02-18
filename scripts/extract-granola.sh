#!/bin/bash
# extract-granola.sh - Extract meetings from Granola cache
#
# Usage:
#   ./scripts/extract-granola.sh              # Today's meetings
#   ./scripts/extract-granola.sh 2026-02-15   # Specific date
#   ./scripts/extract-granola.sh --list-dates # Show available dates
#
# Output: JSON array of meetings with title, time, attendees, transcript availability

CACHE_PATH="${GRANOLA_CACHE_PATH:-$HOME/Library/Application Support/Granola/cache-v3.json}"
TARGET_DATE="${1:-$(date +%Y-%m-%d)}"

if [ ! -f "$CACHE_PATH" ]; then
    echo "Error: Granola cache not found at $CACHE_PATH" >&2
    echo "Set GRANOLA_CACHE_PATH or check Granola installation." >&2
    exit 1
fi

if [ "$1" == "--list-dates" ]; then
    python3 -c "
import json
import sys
from collections import Counter

with open('$CACHE_PATH', 'r') as f:
    data = json.load(f)

cache = json.loads(data['cache'])
documents = cache['state'].get('documents', {})

dates = Counter()
for doc in documents.values():
    created = doc.get('created_at', '')[:10]
    if created:
        dates[created] += 1

for date in sorted(dates.keys(), reverse=True):
    print(f'{date}: {dates[date]} meetings')
"
    exit 0
fi

python3 -c "
import json
import sys
from datetime import datetime

with open('$CACHE_PATH', 'r') as f:
    data = json.load(f)

cache = json.loads(data['cache'])
state = cache['state']
documents = state.get('documents', {})
transcripts = state.get('transcripts', {})

target_date = '$TARGET_DATE'
meetings = []

for doc_id, doc in documents.items():
    created = doc.get('created_at', '')[:10]
    if created != target_date:
        continue

    cal = doc.get('google_calendar_event', {})
    start = cal.get('start', {}).get('dateTime', '')

    attendees = []
    for a in cal.get('attendees', []):
        email = a.get('email', '')
        name = a.get('displayName', email.split('@')[0] if email else '')
        if email and not a.get('self'):
            attendees.append({'email': email, 'name': name})

    trans = transcripts.get(doc_id, [])
    has_transcript = len(trans) > 0
    word_count = len(' '.join([t.get('text', '') for t in trans]).split()) if has_transcript else 0

    meetings.append({
        'id': doc_id,
        'title': cal.get('summary', doc.get('title', 'Untitled')),
        'start': start,
        'attendees': attendees,
        'attendee_count': len(attendees) + 1,  # +1 for self
        'has_transcript': has_transcript,
        'word_count': word_count
    })

# Sort by start time
meetings.sort(key=lambda x: x['start'])

print(json.dumps(meetings, indent=2))
"
