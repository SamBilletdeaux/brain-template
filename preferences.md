# Preferences

Rules and accumulated context that guide how meetings are processed.
This file is read by /wind-down and /wake-up on every run.
Updated through the review process - when corrections are made, the
underlying rule gets captured here so it doesn't happen again.

---

## Sensitivity Rules
- Never document negative performance assessments of named individuals
- Keep personnel opinions and performance evaluations out of people files, threads, and handoffs
- It's fine to note team *dynamics* and *challenges* in general terms, but don't attribute blame or weakness to specific named people
- Don't include information that someone shared "in confidence" or "between us"

## Tracking Rules
- Not every mentioned next-step is a commitment worth tracking. Only track meaningful deliverables with external accountability or deadlines.
- Don't track social/coordination items (scheduling casual meetings, follow-up coffee chats, etc.)
- Don't track items owned by others unless the user has a dependency on them
- When uncertain whether something is a real commitment, err toward not tracking it

## Domain Knowledge
<!-- Accumulated through use. Examples:
- "Standup": Daily 15-min sync at 9:30am
- "OKR review": Quarterly planning meeting with leadership
- Speech-to-text quirks: "Jon" = "John", "Alise" = "Alice", etc.
-->

(Will accumulate as the system learns your domain.)

## Style Preferences
- Keep meeting summaries focused on what's actionable and strategically relevant
- Handoff entries should be scannable - use bullet points, not paragraphs
- Thread files should tell a story over time, not just accumulate facts

## File Structure Rules
- (will accumulate as structure decisions are made)

## System Thresholds
<!-- These are starting guesses. Adjust based on experience. When a threshold fires
     and you say it was too early or too late, update the number here. -->

- **Triage mode trigger**: meetings > 6 OR estimated transcript volume > 50k words (default — not yet tested)
- **Thread pruning suggestion**: dormant threads older than 30 days (default — not yet tested)
- **Thread count warning**: total threads > 20 (default — not yet tested)
- **People file archival suggestion**: people files > 15 (default — not yet tested)
- **Preferences consolidation suggestion**: total rules > 25 (default — not yet tested)
- **Stale commitment flag**: commitment older than 5 days without update (default — not yet tested)
- **Rubber-stamp detection**: 3+ consecutive sessions with zero corrections (default — not yet tested)
- **Low-confidence ratio warning**: >40% of decisions are 🔴 (default — not yet tested)
- **Gap recovery**: >1 day since last wind-down (default — not yet tested)
