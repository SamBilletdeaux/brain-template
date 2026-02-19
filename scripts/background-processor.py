#!/usr/bin/env python3
"""background-processor.py — Process new transcripts into draft updates.

Watches the inbox for new transcript snapshots and generates draft
summaries, entity extractions, and proposed changes for review.

When an Anthropic API key is available, uses Claude for intelligent
summarization. Without one, falls back to rule-based extraction.

Usage:
    python3 scripts/background-processor.py <brain-root> [--once] [--watch-interval 60]

Environment:
    ANTHROPIC_API_KEY — enables AI-powered summarization (optional)
"""

import hashlib
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional


def read_file(path: str) -> str:
    try:
        with open(path, 'r') as f:
            return f.read()
    except FileNotFoundError:
        return ''


def slugify(text: str) -> str:
    slug = text.lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'[\s]+', '-', slug).strip('-')
    return slug[:50]


def get_processed_marker_path(brain_root: str, source_file: str) -> str:
    """Path for the processed marker file."""
    processed_dir = os.path.join(brain_root, 'inbox', '.processed')
    os.makedirs(processed_dir, exist_ok=True)
    file_hash = hashlib.md5(source_file.encode()).hexdigest()[:12]
    return os.path.join(processed_dir, f"bg-{file_hash}")


def is_processed(brain_root: str, source_file: str) -> bool:
    """Check if a file has already been processed by the background processor."""
    return os.path.exists(get_processed_marker_path(brain_root, source_file))


def mark_processed(brain_root: str, source_file: str):
    """Mark a file as processed."""
    marker = get_processed_marker_path(brain_root, source_file)
    with open(marker, 'w') as f:
        f.write(f"{datetime.now().isoformat()}\n{source_file}\n")


def load_people_names(brain_root: str) -> Dict[str, str]:
    """Load known people names for entity matching."""
    people_dir = os.path.join(brain_root, 'people')
    if not os.path.isdir(people_dir):
        return {}

    names = {}
    for fname in os.listdir(people_dir):
        if not fname.endswith('.md'):
            continue
        slug = fname.replace('.md', '')
        display = slug.replace('-', ' ').title()
        names[slug] = display
        for part in slug.split('-'):
            if len(part) > 2:
                names[part] = display

    return names


def load_thread_names(brain_root: str) -> List[str]:
    """Load known thread names."""
    threads_dir = os.path.join(brain_root, 'threads')
    if not os.path.isdir(threads_dir):
        return []
    return [f.replace('.md', '') for f in os.listdir(threads_dir) if f.endswith('.md')]


def extract_transcript_text(snapshot: dict) -> str:
    """Extract readable transcript text from a snapshot."""
    transcript = snapshot.get('transcript', [])
    if isinstance(transcript, list):
        return ' '.join(t.get('text', '') for t in transcript)
    elif isinstance(transcript, str):
        return transcript
    return ''


def rule_based_summary(title: str, transcript: str, attendees: List[str],
                       known_people: Dict[str, str], known_threads: List[str]) -> dict:
    """Generate a basic summary without AI — extract key patterns from text."""
    words = transcript.split()
    word_count = len(words)

    # Find mentioned people
    transcript_lower = transcript.lower()
    mentioned_people = []
    seen = set()
    for key, display in known_people.items():
        if len(key) > 2 and key in transcript_lower and display not in seen:
            mentioned_people.append(display)
            seen.add(display)

    # Find mentioned threads
    mentioned_threads = []
    for thread in known_threads:
        # Check for thread name or its parts
        thread_parts = thread.replace('-', ' ').lower()
        if thread_parts in transcript_lower:
            mentioned_threads.append(thread)

    # Extract potential action items (sentences with action verbs)
    action_patterns = [
        r'(?:need to|should|will|going to|have to|must)\s+\w+.*?[.!]',
        r'(?:action item|next step|follow up|todo)[\s:]+.*?[.!]',
        r'(?:let\'s|we\'ll|i\'ll)\s+\w+.*?[.!]',
    ]
    potential_actions = []
    for pattern in action_patterns:
        matches = re.findall(pattern, transcript_lower)
        potential_actions.extend(matches[:3])

    # Extract potential decisions (sentences with decision language)
    decision_patterns = [
        r'(?:decided|agreed|confirmed|concluded|determined)\s+.*?[.!]',
        r'(?:the plan is|we\'re going with|let\'s go with)\s+.*?[.!]',
    ]
    potential_decisions = []
    for pattern in decision_patterns:
        matches = re.findall(pattern, transcript_lower)
        potential_decisions.extend(matches[:3])

    return {
        'title': title,
        'word_count': word_count,
        'attendees': attendees,
        'mentioned_people': mentioned_people,
        'mentioned_threads': mentioned_threads,
        'potential_actions': potential_actions[:5],
        'potential_decisions': potential_decisions[:5],
        'method': 'rule-based',
    }


def ai_summary(title: str, transcript: str, attendees: List[str],
               known_people: Dict[str, str], known_threads: List[str],
               api_key: str) -> Optional[dict]:
    """Generate an AI-powered summary using Claude API."""
    try:
        import anthropic
    except ImportError:
        print("  anthropic package not installed, falling back to rule-based")
        return None

    people_context = ', '.join(set(known_people.values()))
    threads_context = ', '.join(known_threads)

    # Truncate transcript if too long (keep under ~50k tokens)
    max_chars = 150000
    if len(transcript) > max_chars:
        transcript = transcript[:max_chars] + "\n\n[...transcript truncated...]"

    prompt = f"""Analyze this meeting transcript and extract structured information.

Meeting: {title}
Attendees: {', '.join(attendees) if attendees else 'unknown'}
Known people in the system: {people_context}
Known topic threads: {threads_context}

Transcript:
{transcript}

Return a JSON object with these fields:
- "summary": 2-3 sentence summary of the meeting
- "key_decisions": list of decisions made (each with "decision" text and "confidence" as green/yellow/red)
- "action_items": list of action items (each with "item" text, "owner" if identifiable, "confidence")
- "mentioned_people": list of people mentioned (use display names from the known people list when possible)
- "mentioned_threads": list of topic threads this meeting relates to (from the known threads list)
- "new_thread_candidates": list of topics discussed that don't match existing threads (potential new threads)
- "thread_updates": for each mentioned thread, what new information should be added

Return ONLY the JSON, no other text."""

    client = anthropic.Anthropic(api_key=api_key)
    try:
        message = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2000,
            messages=[{"role": "user", "content": prompt}],
        )
        response_text = message.content[0].text

        # Parse JSON from response
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            result = json.loads(json_match.group())
            result['method'] = 'ai'
            result['title'] = title
            result['attendees'] = attendees
            return result
    except Exception as e:
        print(f"  AI summary failed: {e}")

    return None


def generate_draft_file(summary: dict, source_file: str, brain_root: str) -> str:
    """Generate a draft markdown file from a summary."""
    lines = [
        f"# Draft: {summary['title']}",
        f"",
        f"**Source**: `{os.path.basename(source_file)}`",
        f"**Processed**: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"**Method**: {summary.get('method', 'unknown')}",
        f"",
    ]

    if summary.get('attendees'):
        lines.append(f"**Attendees**: {', '.join(summary['attendees'])}")
        lines.append("")

    lines.extend(["---", ""])

    # AI-generated summary
    if summary.get('summary'):
        lines.extend([
            "## Summary",
            "",
            summary['summary'],
            "",
        ])

    # Mentioned people
    if summary.get('mentioned_people'):
        lines.extend([
            "## People Mentioned",
            "",
        ])
        for p in summary['mentioned_people']:
            lines.append(f"- {p}")
        lines.append("")

    # Related threads
    if summary.get('mentioned_threads'):
        lines.extend([
            "## Related Threads",
            "",
        ])
        for t in summary['mentioned_threads']:
            lines.append(f"- [[{t}]]")
        lines.append("")

    # Decisions
    decisions = summary.get('key_decisions') or summary.get('potential_decisions', [])
    if decisions:
        lines.extend([
            "## Decisions",
            "",
        ])
        for d in decisions:
            if isinstance(d, dict):
                conf = d.get('confidence', 'yellow')
                emoji = {'green': '\U0001f7e2', 'yellow': '\U0001f7e1', 'red': '\U0001f534'}.get(conf, '\U0001f7e1')
                lines.append(f"- {emoji} {d.get('decision', d.get('item', str(d)))}")
            else:
                lines.append(f"- \U0001f7e1 {d}")
        lines.append("")

    # Action items
    actions = summary.get('action_items') or summary.get('potential_actions', [])
    if actions:
        lines.extend([
            "## Potential Action Items",
            "",
        ])
        for a in actions:
            if isinstance(a, dict):
                owner = f" — @{a['owner']}" if a.get('owner') else ""
                lines.append(f"- [ ] {a.get('item', str(a))}{owner}")
            else:
                lines.append(f"- [ ] {a}")
        lines.append("")

    # New thread candidates (AI only)
    if summary.get('new_thread_candidates'):
        lines.extend([
            "## Possible New Threads",
            "",
        ])
        for t in summary['new_thread_candidates']:
            lines.append(f"- {t}")
        lines.append("")

    # Thread updates (AI only)
    if summary.get('thread_updates'):
        lines.extend([
            "## Proposed Thread Updates",
            "",
        ])
        if isinstance(summary['thread_updates'], dict):
            for thread, update in summary['thread_updates'].items():
                lines.append(f"### [[{thread}]]")
                lines.append(f"{update}")
                lines.append("")
        elif isinstance(summary['thread_updates'], list):
            for update in summary['thread_updates']:
                if isinstance(update, dict):
                    thread = update.get('thread', 'unknown')
                    text = update.get('update', str(update))
                    lines.append(f"### [[{thread}]]")
                    lines.append(f"{text}")
                    lines.append("")

    lines.extend([
        "---",
        f"_Review this draft during /wind-down. Approve, edit, or reject each section._",
    ])

    return '\n'.join(lines)


def process_snapshot(snapshot_path: str, brain_root: str,
                     known_people: Dict[str, str], known_threads: List[str],
                     api_key: Optional[str]) -> Optional[str]:
    """Process a single transcript snapshot into a draft."""
    try:
        with open(snapshot_path, 'r') as f:
            snapshot = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError):
        return None

    title = snapshot.get('title', 'Untitled')
    transcript = extract_transcript_text(snapshot)

    if not transcript or len(transcript.split()) < 50:
        return None  # skip very short transcripts

    # Extract attendee names
    cal = snapshot.get('google_calendar_event') or {}
    attendees = []
    for a in (cal.get('attendees') or []):
        name = a.get('displayName', a.get('email', '').split('@')[0])
        if not a.get('self') and name:
            attendees.append(name)

    # Try AI summary first, fall back to rule-based
    summary = None
    if api_key:
        print(f"  Using AI for: {title}")
        summary = ai_summary(title, transcript, attendees,
                            known_people, known_threads, api_key)

    if not summary:
        summary = rule_based_summary(title, transcript, attendees,
                                     known_people, known_threads)

    # Generate draft file
    drafts_dir = os.path.join(brain_root, 'inbox', 'drafts')
    os.makedirs(drafts_dir, exist_ok=True)

    date = snapshot.get('created_at', '')[:10] or datetime.now().strftime('%Y-%m-%d')
    slug = slugify(title)
    filename = f"{date}-{slug}.md"
    filepath = os.path.join(drafts_dir, filename)

    draft_content = generate_draft_file(summary, snapshot_path, brain_root)

    with open(filepath, 'w') as f:
        f.write(draft_content)

    return filename


def scan_and_process(brain_root: str, api_key: Optional[str], limit: int = 0):
    """Scan inbox for unprocessed snapshots and process them."""
    granola_dir = os.path.join(brain_root, 'inbox', 'granola')
    if not os.path.isdir(granola_dir):
        print("No inbox/granola directory found")
        return 0

    known_people = load_people_names(brain_root)
    known_threads = load_thread_names(brain_root)

    # Find all JSON files recursively (snapshots may be in date subdirs)
    json_files = []
    for root, dirs, files in os.walk(granola_dir):
        for f in files:
            if f.endswith('.json'):
                json_files.append(os.path.join(root, f))
    json_files.sort()

    processed_count = 0

    for fpath in json_files:
        if is_processed(brain_root, fpath):
            continue

        fname = os.path.basename(fpath)
        print(f"Processing: {fname}")
        result = process_snapshot(fpath, brain_root, known_people, known_threads, api_key)

        if result:
            print(f"  → {result}")
            processed_count += 1
        else:
            print(f"  → skipped (no transcript or too short)")

        mark_processed(brain_root, fpath)

        if limit and processed_count >= limit:
            break

    return processed_count


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 background-processor.py <brain-root> [--once] [--watch-interval 60]")
        sys.exit(1)

    brain_root = os.path.expanduser(sys.argv[1])
    api_key = os.environ.get('ANTHROPIC_API_KEY')

    once = '--once' in sys.argv
    watch_interval = 60  # seconds

    for i, arg in enumerate(sys.argv):
        if arg == '--watch-interval' and i + 1 < len(sys.argv):
            watch_interval = int(sys.argv[i + 1])

    if api_key:
        print("Anthropic API key found — AI summaries enabled")
    else:
        print("No ANTHROPIC_API_KEY — using rule-based extraction")

    if once:
        count = scan_and_process(brain_root, api_key)
        print(f"\nProcessed {count} new transcript(s)")
    else:
        print(f"Watching for new transcripts (every {watch_interval}s)...")
        print("Press Ctrl+C to stop")
        while True:
            count = scan_and_process(brain_root, api_key)
            if count > 0:
                print(f"Processed {count} new transcript(s)")
                # Send notification
                notify_script = os.path.join(os.path.dirname(__file__), 'notify.sh')
                if os.path.exists(notify_script):
                    os.system(f'"{notify_script}" "Brain" "{count} transcript(s) processed" --sound')
            time.sleep(watch_interval)


if __name__ == '__main__':
    main()
