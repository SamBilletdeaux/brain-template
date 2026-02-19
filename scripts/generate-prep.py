#!/usr/bin/env python3
"""generate-prep.py — Auto-generate meeting prep packets.

Reads today's calendar from Granola cache (or inbox/calendar/),
cross-references people files, threads, and commitments,
and writes a prep markdown file for each upcoming meeting.

Usage:
    python3 scripts/generate-prep.py <brain-root> [--date YYYY-MM-DD] [--hours-ahead N]

Output:
    inbox/prep/YYYY-MM-DD-meeting-slug.md (one per meeting)
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Optional


def load_granola_meetings(cache_path: str, target_date: str) -> List[dict]:
    """Extract meetings from Granola cache for a given date."""
    if not os.path.exists(cache_path):
        return []

    with open(cache_path, 'r') as f:
        data = json.load(f)

    cache = json.loads(data['cache'])
    state = cache['state']
    documents = state.get('documents', {})

    meetings = []
    for doc_id, doc in documents.items():
        created = doc.get('created_at', '')[:10]
        if created != target_date:
            continue

        cal = doc.get('google_calendar_event') or {}
        start_obj = cal.get('start') or {}
        start = start_obj.get('dateTime', '')

        attendees = []
        for a in (cal.get('attendees') or []):
            email = a.get('email', '')
            name = a.get('displayName', email.split('@')[0] if email else '')
            if email and not a.get('self'):
                attendees.append({'email': email, 'name': name})

        meetings.append({
            'id': doc_id,
            'title': cal.get('summary', doc.get('title', 'Untitled')),
            'start': start,
            'attendees': attendees,
        })

    meetings.sort(key=lambda x: x.get('start', ''))
    return meetings


def load_inbox_meetings(inbox_path: str, target_date: str) -> List[dict]:
    """Load meetings from inbox snapshots as fallback."""
    granola_dir = os.path.join(inbox_path, 'granola')
    if not os.path.isdir(granola_dir):
        return []

    meetings = []
    for fname in os.listdir(granola_dir):
        if not fname.endswith('.json'):
            continue
        fpath = os.path.join(granola_dir, fname)
        try:
            with open(fpath, 'r') as f:
                doc = json.load(f)
            created = doc.get('created_at', '')[:10]
            if created != target_date:
                continue

            cal = doc.get('google_calendar_event') or {}
            start_obj = cal.get('start') or {}
            start = start_obj.get('dateTime', '')

            attendees = []
            for a in (cal.get('attendees') or []):
                email = a.get('email', '')
                name = a.get('displayName', email.split('@')[0] if email else '')
                if email and not a.get('self'):
                    attendees.append({'email': email, 'name': name})

            meetings.append({
                'id': doc.get('id', fname),
                'title': cal.get('summary', doc.get('title', 'Untitled')),
                'start': start,
                'attendees': attendees,
            })
        except (json.JSONDecodeError, KeyError):
            continue

    meetings.sort(key=lambda x: x.get('start', ''))
    return meetings


def slugify(text: str) -> str:
    """Convert text to a filename-safe slug."""
    slug = text.lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'[\s]+', '-', slug).strip('-')
    return slug[:60]


def find_people_files(brain_root: str) -> Dict[str, str]:
    """Build a lookup from name fragments to people file paths."""
    people_dir = os.path.join(brain_root, 'people')
    if not os.path.isdir(people_dir):
        return {}

    people = {}
    for fname in os.listdir(people_dir):
        if not fname.endswith('.md'):
            continue
        slug = fname.replace('.md', '')
        # Index by full slug and each part of the name
        people[slug] = os.path.join(people_dir, fname)
        for part in slug.split('-'):
            if len(part) > 2:  # skip initials
                people[part] = os.path.join(people_dir, fname)

    return people


def match_attendee_to_person(attendee: dict, people_lookup: Dict[str, str]) -> Optional[str]:
    """Try to match an attendee to a people file."""
    name = attendee.get('name', '').lower().strip()
    email = attendee.get('email', '').lower()

    # Try full name as slug
    slug = re.sub(r'[^a-z0-9\s]', '', name)
    slug = re.sub(r'\s+', '-', slug).strip('-')
    if slug in people_lookup:
        return people_lookup[slug]

    # Try first name
    first = name.split()[0] if name else email.split('@')[0]
    first = re.sub(r'[^a-z]', '', first)
    if first in people_lookup:
        return people_lookup[first]

    # Try last name
    parts = name.split()
    if len(parts) > 1:
        last = re.sub(r'[^a-z]', '', parts[-1])
        if last in people_lookup:
            return people_lookup[last]

    return None


def read_file_content(path: str) -> str:
    """Read a file, return empty string if missing."""
    try:
        with open(path, 'r') as f:
            return f.read()
    except FileNotFoundError:
        return ''


def expand_name_variants(names: List[str]) -> Dict[str, str]:
    """Expand a list of names into search variants mapped back to display name."""
    variants = {}
    for name in names:
        name_clean = name.strip()
        if not name_clean:
            continue
        variants[name_clean.lower()] = name_clean
        # Add first name
        parts = name_clean.split()
        if parts:
            variants[parts[0].lower()] = name_clean
        # Add last name if multi-part
        if len(parts) > 1:
            variants[parts[-1].lower()] = name_clean
    return variants


def find_relevant_threads(brain_root: str, attendee_names: List[str]) -> List[dict]:
    """Find threads that mention any of the attendees."""
    threads_dir = os.path.join(brain_root, 'threads')
    if not os.path.isdir(threads_dir):
        return []

    name_variants = expand_name_variants(attendee_names)

    relevant = []
    for fname in os.listdir(threads_dir):
        if not fname.endswith('.md'):
            continue
        content = read_file_content(os.path.join(threads_dir, fname))
        content_lower = content.lower()

        # Check if any attendee name variant appears in the thread
        matched_names = set()
        for variant, display_name in name_variants.items():
            if len(variant) > 2 and re.search(r'\b' + re.escape(variant) + r'\b', content_lower):
                matched_names.add(display_name)

        if matched_names:
            # Extract status if present
            status_match = re.search(r'\*\*Status\*\*:\s*(.+)', content)
            status = status_match.group(1).strip() if status_match else 'unknown'

            relevant.append({
                'name': fname.replace('.md', ''),
                'status': status,
                'matched_people': list(matched_names),
                'path': os.path.join(threads_dir, fname),
            })

    return relevant


def find_relevant_commitments(brain_root: str, attendee_names: List[str]) -> List[str]:
    """Find active commitments that mention any attendee."""
    commitments_path = os.path.join(brain_root, 'commitments.md')
    content = read_file_content(commitments_path)
    if not content:
        return []

    # Extract active section
    active_match = re.search(r'## Active\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
    if not active_match:
        return []

    name_variants = expand_name_variants(attendee_names)
    active_lines = active_match.group(1).strip().split('\n')
    relevant = []

    for line in active_lines:
        if not line.startswith('- [ ]'):
            continue
        line_lower = line.lower()
        for variant in name_variants:
            if len(variant) > 2 and variant in line_lower:
                relevant.append(line.replace('- [ ] ', ''))
                break

    return relevant


def find_recent_handoff_mentions(brain_root: str, attendee_names: List[str], limit: int = 3) -> List[str]:
    """Find recent handoff entries that mention attendees."""
    handoff_path = os.path.join(brain_root, 'handoff.md')
    content = read_file_content(handoff_path)
    if not content:
        return []

    name_variants = expand_name_variants(attendee_names)

    # Split into date sections
    sections = re.split(r'^## ', content, flags=re.MULTILINE)[1:]
    mentions = []

    for section in sections[:5]:  # only check last 5 entries
        section_lower = section.lower()
        for variant in name_variants:
            if len(variant) > 2 and variant in section_lower:
                header = section.split('\n')[0].strip()
                mentions.append(header)
                break
        if len(mentions) >= limit:
            break

    return mentions


def infer_attendees_from_title(title: str, people_lookup: Dict[str, str]) -> List[dict]:
    """Try to match known people names in the meeting title."""
    title_lower = title.lower()
    matched = []
    seen_paths = set()
    for key, path in people_lookup.items():
        if len(key) > 2 and key in title_lower and path not in seen_paths:
            name = os.path.basename(path).replace('.md', '').replace('-', ' ').title()
            matched.append({'name': name, 'email': '', '_inferred': True})
            seen_paths.add(path)
    return matched


def generate_prep(meeting: dict, brain_root: str, people_lookup: Dict[str, str]) -> str:
    """Generate a prep packet for a single meeting."""
    title = meeting['title']
    start = meeting.get('start', '')
    attendees = meeting.get('attendees', [])

    # If no attendees from calendar, try to infer from title
    if not attendees:
        attendees = infer_attendees_from_title(title, people_lookup)

    # Format time
    time_str = ''
    if start:
        try:
            dt = datetime.fromisoformat(start.replace('Z', '+00:00'))
            time_str = dt.strftime('%I:%M %p').lstrip('0')
        except (ValueError, TypeError):
            time_str = start

    lines = [
        f"# Meeting Prep: {title}",
        f"",
        f"**Time**: {time_str}" if time_str else "",
        f"**Attendees**: {', '.join(a['name'] or a['email'] for a in attendees)}",
        f"",
        f"---",
        f"",
    ]

    # Attendee context
    attendee_names = []
    lines.append("## Attendee Context")
    lines.append("")

    if not attendees:
        lines.append("_No attendees listed._")
        lines.append("")
    else:
        for attendee in attendees:
            name = attendee.get('name', attendee.get('email', 'Unknown'))
            attendee_names.append(name)
            person_path = match_attendee_to_person(attendee, people_lookup)

            if person_path:
                person_content = read_file_content(person_path)
                # Extract key sections (role, current focus, etc.)
                role_match = re.search(r'\*\*Role\*\*:\s*(.+)', person_content)
                focus_match = re.search(r'\*\*(?:Current )?Focus\*\*:\s*(.+)', person_content, re.IGNORECASE)

                slug = os.path.basename(person_path).replace('.md', '')
                lines.append(f"### {name} → [[{slug}]]")
                if role_match:
                    lines.append(f"- Role: {role_match.group(1).strip()}")
                if focus_match:
                    lines.append(f"- Focus: {focus_match.group(1).strip()}")

                # Extract recent context (last few bullet points from the person file)
                bullets = re.findall(r'^- .+', person_content, re.MULTILINE)
                if bullets:
                    lines.append(f"- Recent notes: {bullets[-1].replace('- ', '')}")
            else:
                lines.append(f"### {name}")
                lines.append(f"- _No people file found_")

            lines.append("")

    # Relevant threads
    threads = find_relevant_threads(brain_root, attendee_names)
    if threads:
        lines.append("## Relevant Threads")
        lines.append("")
        for t in threads:
            people_str = ', '.join(t['matched_people'])
            lines.append(f"- [[{t['name']}]] (status: {t['status']}) — connected to {people_str}")
        lines.append("")

    # Open commitments
    commitments = find_relevant_commitments(brain_root, attendee_names)
    if commitments:
        lines.append("## Open Commitments")
        lines.append("")
        for c in commitments:
            lines.append(f"- [ ] {c}")
        lines.append("")

    # Recent handoff mentions
    mentions = find_recent_handoff_mentions(brain_root, attendee_names)
    if mentions:
        lines.append("## Recent Context")
        lines.append("")
        for m in mentions:
            lines.append(f"- Referenced in: {m}")
        lines.append("")

    # Footer
    lines.append("---")
    lines.append(f"_Auto-generated {datetime.now().strftime('%Y-%m-%d %H:%M')}_")

    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate-prep.py <brain-root> [--date YYYY-MM-DD] [--hours-ahead N]")
        sys.exit(1)

    brain_root = os.path.expanduser(sys.argv[1])

    # Parse optional args
    target_date = datetime.now().strftime('%Y-%m-%d')
    hours_ahead = 24  # generate prep for meetings in next N hours

    args = sys.argv[2:]
    for i, arg in enumerate(args):
        if arg == '--date' and i + 1 < len(args):
            target_date = args[i + 1]
        elif arg == '--hours-ahead' and i + 1 < len(args):
            hours_ahead = int(args[i + 1])

    # Load config to find cache path
    config_path = os.path.join(brain_root, 'config.md')
    cache_path = os.path.expanduser('~/Library/Application Support/Granola/cache-v3.json')
    if os.path.exists(config_path):
        config = read_file_content(config_path)
        cache_match = re.search(r'Cache path:\s*`([^`]+)`', config)
        if cache_match:
            cache_path = os.path.expanduser(cache_match.group(1))

    # Get meetings — try Granola cache first, then inbox
    meetings = load_granola_meetings(cache_path, target_date)
    if not meetings:
        inbox_path = os.path.join(brain_root, 'inbox')
        meetings = load_inbox_meetings(inbox_path, target_date)

    if not meetings:
        print(f"No meetings found for {target_date}")
        sys.exit(0)

    # Filter to upcoming meetings only (within hours_ahead window)
    now = datetime.now().astimezone()
    cutoff = now + timedelta(hours=hours_ahead)
    upcoming = []
    for m in meetings:
        start = m.get('start', '')
        if not start:
            upcoming.append(m)  # include meetings without times
            continue
        try:
            meeting_time = datetime.fromisoformat(start.replace('Z', '+00:00'))
            if meeting_time >= now and meeting_time <= cutoff:
                upcoming.append(m)
        except (ValueError, TypeError):
            upcoming.append(m)

    if not upcoming:
        print(f"No upcoming meetings in next {hours_ahead} hours")
        sys.exit(0)

    # Build people lookup
    people_lookup = find_people_files(brain_root)

    # Generate prep for each meeting
    prep_dir = os.path.join(brain_root, 'inbox', 'prep')
    os.makedirs(prep_dir, exist_ok=True)

    generated = []
    for meeting in upcoming:
        slug = slugify(meeting['title'])
        filename = f"{target_date}-{slug}.md"
        filepath = os.path.join(prep_dir, filename)

        prep_content = generate_prep(meeting, brain_root, people_lookup)

        with open(filepath, 'w') as f:
            f.write(prep_content)

        generated.append(filename)
        print(f"Generated: {filename}")

    print(f"\n{len(generated)} prep packet(s) in {prep_dir}")


if __name__ == '__main__':
    main()
