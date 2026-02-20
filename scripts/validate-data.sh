#!/usr/bin/env bash
# validate-data.sh — Data consistency validation for the brain
#
# Usage: ./scripts/validate-data.sh [brain-root]
# Exit codes: 0 = clean, 1 = warnings, 2 = errors

set -euo pipefail

BRAIN_ROOT="${1:-$HOME/brain}"

python3 - "$BRAIN_ROOT" << 'PYTHON_SCRIPT'
import sys
import os
import re
from datetime import datetime

brain_root = sys.argv[1]
errors = []
warnings = []

# 1. Check [[wiki-links]] resolve to real files
for subdir in ['threads', 'people']:
    dirpath = os.path.join(brain_root, subdir)
    if not os.path.isdir(dirpath):
        continue
    for fname in os.listdir(dirpath):
        if not fname.endswith('.md'):
            continue
        fpath = os.path.join(dirpath, fname)
        with open(fpath, 'r') as f:
            content = f.read()
        links = re.findall(r'\[\[([^\]]+)\]\]', content)
        for link in links:
            slug = link.lower().replace(' ', '-')
            person_path = os.path.join(brain_root, 'people', f'{slug}.md')
            thread_path = os.path.join(brain_root, 'threads', f'{slug}.md')
            if not os.path.exists(person_path) and not os.path.exists(thread_path):
                warnings.append(f"Broken link [[{link}]] in {subdir}/{fname}")

# 2. Check handoff.md dates in reverse chronological order
handoff_path = os.path.join(brain_root, 'handoff.md')
if os.path.exists(handoff_path):
    with open(handoff_path, 'r') as f:
        content = f.read()
    dates = re.findall(r'^## (\d{4}-\d{2}-\d{2})', content, re.MULTILINE)
    for i in range(len(dates) - 1):
        if dates[i] < dates[i + 1]:
            errors.append(f"handoff.md dates out of order: {dates[i]} before {dates[i+1]}")

# 3. Check for duplicate commitments
commitments_path = os.path.join(brain_root, 'commitments.md')
if os.path.exists(commitments_path):
    with open(commitments_path, 'r') as f:
        content = f.read()
    items = re.findall(r'^- \[[ x]\] (.+)', content, re.MULTILINE)
    # Normalize for comparison
    normalized = {}
    for item in items:
        key = re.sub(r'\s+', ' ', item.strip().lower())
        if key in normalized:
            warnings.append(f"Duplicate commitment: {item.strip()[:60]}...")
        else:
            normalized[key] = True

# 4. Check for empty thread/people files
for subdir in ['threads', 'people']:
    dirpath = os.path.join(brain_root, subdir)
    if not os.path.isdir(dirpath):
        continue
    for fname in os.listdir(dirpath):
        if not fname.endswith('.md'):
            continue
        fpath = os.path.join(dirpath, fname)
        with open(fpath, 'r') as f:
            content = f.read().strip()
        if not content:
            errors.append(f"Empty file: {subdir}/{fname}")
        elif not re.match(r'^#\s', content):
            warnings.append(f"Missing heading: {subdir}/{fname}")

# 5. Check health.md rows in chronological order
health_path = os.path.join(brain_root, 'health.md')
if os.path.exists(health_path):
    with open(health_path, 'r') as f:
        content = f.read()
    # Look for dates in the history table (pipe-delimited rows)
    history_dates = re.findall(r'\|\s*(\d{4}-\d{2}-\d{2})\s*\|', content)
    for i in range(len(history_dates) - 1):
        if history_dates[i] > history_dates[i + 1]:
            warnings.append(f"health.md history out of order: {history_dates[i]} before {history_dates[i+1]}")

# Output
if errors:
    print(f"ERRORS ({len(errors)}):")
    for e in errors:
        print(f"  ✗ {e}")
if warnings:
    print(f"WARNINGS ({len(warnings)}):")
    for w in warnings:
        print(f"  ⚠ {w}")

if not errors and not warnings:
    print("Data validation: clean")
    sys.exit(0)
elif errors:
    sys.exit(2)
else:
    sys.exit(1)
PYTHON_SCRIPT
