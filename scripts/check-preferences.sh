#!/usr/bin/env bash
# check-preferences.sh — Detect contradictions, near-duplicates, and bloat in preferences.md
#
# Usage: ./scripts/check-preferences.sh [brain-root]
# Exit codes: 0 = clean, 1 = warnings found

set -euo pipefail

BRAIN_ROOT="${1:-$HOME/brain}"
PREFS_FILE="$BRAIN_ROOT/preferences.md"

if [ ! -f "$PREFS_FILE" ]; then
  echo "No preferences.md found at $PREFS_FILE"
  exit 0
fi

python3 - "$PREFS_FILE" << 'PYTHON_SCRIPT'
import sys
import re
from collections import defaultdict

prefs_file = sys.argv[1]

with open(prefs_file, 'r') as f:
    content = f.read()

# Extract rules: lines starting with "- " that aren't placeholders/comments
rules = []
for line in content.split('\n'):
    line = line.strip()
    if line.startswith('- ') and not line.startswith('- (') and not line.startswith('- **'):
        rule_text = line[2:].strip()
        if rule_text and not rule_text.startswith('<!--'):
            rules.append(rule_text)

warnings = []

# 1. Contradiction detection: opposing verbs about the same topic
OPPOSING_PATTERNS = [
    (r'\balways\b', r'\bnever\b'),
    (r'\bdon\'?t\b', r'\bdo\b'),
    (r'\btrack\b', r'\bdon\'?t track\b'),
    (r'\binclude\b', r'\bexclude\b'),
    (r'\binclude\b', r'\bdon\'?t include\b'),
    (r'\bskip\b', r'\bdon\'?t skip\b'),
]

def get_topic_words(rule):
    """Extract content words (nouns/adjectives) from a rule."""
    stop_words = {'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been',
                  'do', 'does', 'did', 'will', 'would', 'could', 'should',
                  'have', 'has', 'had', 'not', 'no', 'and', 'or', 'but',
                  'in', 'on', 'at', 'to', 'for', 'of', 'with', 'from',
                  'that', 'this', 'it', 'they', 'them', 'their', 'when',
                  'if', 'as', 'than', 'just', 'only', 'also', 'too',
                  'don\'t', 'always', 'never', 'every', 'any'}
    words = set(re.findall(r'\b\w+\b', rule.lower()))
    return words - stop_words

for i, rule_a in enumerate(rules):
    for j, rule_b in enumerate(rules):
        if j <= i:
            continue
        topic_a = get_topic_words(rule_a)
        topic_b = get_topic_words(rule_b)
        if not topic_a or not topic_b:
            continue
        overlap = topic_a & topic_b
        union = topic_a | topic_b
        if len(union) == 0:
            continue
        topic_similarity = len(overlap) / len(union)

        # Check for opposing patterns
        if topic_similarity > 0.3:
            for pat_a, pat_b in OPPOSING_PATTERNS:
                if ((re.search(pat_a, rule_a, re.I) and re.search(pat_b, rule_b, re.I)) or
                    (re.search(pat_b, rule_a, re.I) and re.search(pat_a, rule_b, re.I))):
                    warnings.append(f"CONFLICT: These rules may contradict each other:\n  1: {rule_a}\n  2: {rule_b}")
                    break

# 2. Near-duplicate detection (>70% word overlap)
for i, rule_a in enumerate(rules):
    for j, rule_b in enumerate(rules):
        if j <= i:
            continue
        words_a = set(re.findall(r'\b\w+\b', rule_a.lower()))
        words_b = set(re.findall(r'\b\w+\b', rule_b.lower()))
        if not words_a or not words_b:
            continue
        overlap = len(words_a & words_b)
        smaller = min(len(words_a), len(words_b))
        if smaller > 0 and overlap / smaller > 0.7:
            # Skip if already flagged as conflict
            already_flagged = any(rule_a in w and rule_b in w for w in warnings)
            if not already_flagged:
                warnings.append(f"NEAR-DUPLICATE: These rules are very similar:\n  1: {rule_a}\n  2: {rule_b}")

# 3. Size warning
if len(rules) > 25:
    warnings.append(f"SIZE: preferences.md has {len(rules)} rules. Consider consolidating overlapping rules.")

# Output
if warnings:
    print(f"preferences.md: {len(warnings)} warning(s) found\n")
    for w in warnings:
        print(f"  ⚠️  {w}\n")
    sys.exit(1)
else:
    print(f"preferences.md: clean ({len(rules)} rules)")
    sys.exit(0)
PYTHON_SCRIPT
