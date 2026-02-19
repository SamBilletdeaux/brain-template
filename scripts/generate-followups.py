#!/usr/bin/env python3
"""generate-followups.py — Draft follow-up messages for action items.

Reads commitments.md, identifies items that look like "send X to Y" or
"share X with Y", and generates draft messages using context from
people files, threads, and handoff entries.

Usage:
    python3 scripts/generate-followups.py <brain-root>

Output:
    inbox/drafts/follow-ups/YYYY-MM-DD-commitment-slug.md
"""

import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional


# Patterns that suggest a follow-up message is needed
FOLLOWUP_PATTERNS = [
    r'share\b.*\bwith\b',
    r'send\b.*\bto\b',
    r'follow.?up\b.*\bwith\b',
    r'email\b',
    r'slack\b.*\b(?:to|with)\b',
    r'update\b.*\bon\b',
    r'let\b.*\bknow\b',
    r'reach out\b',
    r'message\b',
    r'ping\b',
    r'loop in\b',
    r'circle back\b',
]


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


def extract_active_commitments(brain_root: str) -> List[dict]:
    """Parse active commitments from commitments.md."""
    content = read_file(os.path.join(brain_root, 'commitments.md'))
    if not content:
        return []

    active_match = re.search(r'## Active\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
    if not active_match:
        return []

    commitments = []
    for line in active_match.group(1).strip().split('\n'):
        if not line.startswith('- [ ]'):
            continue

        text = line.replace('- [ ] ', '').strip()

        # Extract metadata
        owner_match = re.search(r'@(\w+)', text)
        date_match = re.search(r'added (\d{4}-\d{2}-\d{2})', text)
        source_match = re.search(r'from (.+?)(?:\s*$)', text)

        commitments.append({
            'text': text,
            'owner': owner_match.group(1) if owner_match else None,
            'added_date': date_match.group(1) if date_match else None,
            'source': source_match.group(1) if source_match else None,
        })

    return commitments


def is_followup_commitment(text: str) -> bool:
    """Check if a commitment looks like it needs a follow-up message."""
    text_lower = text.lower()
    for pattern in FOLLOWUP_PATTERNS:
        if re.search(pattern, text_lower):
            return True
    return False


def extract_recipient(text: str, people_lookup: Dict[str, str]) -> Optional[dict]:
    """Try to extract who the message should go to."""
    text_lower = text.lower()

    # Try patterns like "send X to Y", "share X with Y"
    recipient_patterns = [
        r'(?:to|with)\s+(\w+(?:\s+\w+)?)\b',
        r'(?:let|tell|inform)\s+(\w+)\b',
        r'(?:ping|message|email|slack)\s+(\w+)\b',
    ]

    for pattern in recipient_patterns:
        match = re.search(pattern, text_lower)
        if match:
            name = match.group(1).strip()
            # Check if this name matches a known person
            for key, path in people_lookup.items():
                if key in name.split():
                    display = os.path.basename(path).replace('.md', '').replace('-', ' ').title()
                    return {'name': display, 'path': path}

    return None


def find_people_files(brain_root: str) -> Dict[str, str]:
    """Build name -> path lookup for people files."""
    people_dir = os.path.join(brain_root, 'people')
    if not os.path.isdir(people_dir):
        return {}

    people = {}
    for fname in os.listdir(people_dir):
        if not fname.endswith('.md'):
            continue
        slug = fname.replace('.md', '')
        people[slug] = os.path.join(people_dir, fname)
        for part in slug.split('-'):
            if len(part) > 2:
                people[part] = os.path.join(people_dir, fname)

    return people


def get_relevant_context(brain_root: str, commitment_text: str) -> str:
    """Find related context from handoff and threads."""
    context_lines = []

    # Check handoff for related mentions
    handoff = read_file(os.path.join(brain_root, 'handoff.md'))
    sections = re.split(r'^## ', handoff, flags=re.MULTILINE)[1:]

    # Extract key terms from the commitment (skip common words)
    terms = set()
    for word in re.findall(r'\b\w{4,}\b', commitment_text.lower()):
        if word not in ('with', 'from', 'that', 'this', 'they', 'them', 'their',
                        'have', 'been', 'will', 'would', 'should', 'could',
                        'added', 'about', 'share', 'send', 'team'):
            terms.add(word)

    for section in sections[:3]:
        section_lower = section.lower()
        matched_terms = [t for t in terms if t in section_lower]
        if len(matched_terms) >= 2:
            header = section.split('\n')[0].strip()
            # Find the specific bullet points that match
            for line in section.split('\n'):
                line_lower = line.lower()
                if any(t in line_lower for t in matched_terms) and line.strip().startswith('-'):
                    context_lines.append(f"  - From {header}: {line.strip()}")
                    if len(context_lines) >= 3:
                        break

    return '\n'.join(context_lines)


def generate_draft(commitment: dict, recipient: Optional[dict],
                   context: str, brain_root: str) -> str:
    """Generate a follow-up draft markdown file."""
    lines = [
        f"# Follow-Up Draft",
        f"",
        f"**Commitment**: {commitment['text']}",
        f"**Added**: {commitment.get('added_date', 'unknown')}",
    ]

    if commitment.get('source'):
        lines.append(f"**Source meeting**: {commitment['source']}")

    if recipient:
        slug = os.path.basename(recipient['path']).replace('.md', '')
        lines.append(f"**Recipient**: [[{slug}]]")

        # Read person context
        person_content = read_file(recipient['path'])
        role_match = re.search(r'\*\*Role\*\*:\s*(.+)', person_content)
        if role_match:
            lines.append(f"**Their role**: {role_match.group(1).strip()}")

    lines.extend([
        f"",
        f"---",
        f"",
    ])

    if context:
        lines.extend([
            f"## Related Context",
            f"",
            context,
            f"",
            f"---",
            f"",
        ])

    lines.extend([
        f"## Draft Message",
        f"",
        f"> **Subject**: [TODO — suggested: Re: {commitment.get('source', 'Follow-up')}]",
        f">",
        f"> Hi{' ' + recipient['name'].split()[0] if recipient else ''},",
        f">",
        f"> Following up from our conversation — [TODO: complete this draft]",
        f">",
        f"> [The commitment was: {commitment['text'].split(' — ')[0]}]",
        f">",
        f"> Best,",
        f"> [Your name]",
        f"",
        f"---",
        f"_Auto-generated {datetime.now().strftime('%Y-%m-%d %H:%M')}. Edit before sending._",
    ])

    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate-followups.py <brain-root>")
        sys.exit(1)

    brain_root = os.path.expanduser(sys.argv[1])
    people_lookup = find_people_files(brain_root)
    commitments = extract_active_commitments(brain_root)

    if not commitments:
        print("No active commitments found")
        sys.exit(0)

    # Filter to follow-up-able commitments
    followups = [c for c in commitments if is_followup_commitment(c['text'])]

    if not followups:
        print("No commitments need follow-up messages")
        sys.exit(0)

    # Generate drafts
    drafts_dir = os.path.join(brain_root, 'inbox', 'drafts', 'follow-ups')
    os.makedirs(drafts_dir, exist_ok=True)

    today = datetime.now().strftime('%Y-%m-%d')
    generated = []

    for commitment in followups:
        slug = slugify(commitment['text'])
        filename = f"{today}-{slug}.md"
        filepath = os.path.join(drafts_dir, filename)

        # Skip if already generated today
        if os.path.exists(filepath):
            print(f"Skipped (exists): {filename}")
            continue

        recipient = extract_recipient(commitment['text'], people_lookup)
        context = get_relevant_context(brain_root, commitment['text'])
        draft = generate_draft(commitment, recipient, context, brain_root)

        with open(filepath, 'w') as f:
            f.write(draft)

        generated.append(filename)
        print(f"Generated: {filename}")

    print(f"\n{len(generated)} draft(s) in {drafts_dir}")


if __name__ == '__main__':
    main()
