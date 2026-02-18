# brain

A living knowledge system that processes your daily meetings into evolving notes about threads, people, and commitments. Built to run with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## What is this?

Most meeting notes die the moment you close the doc. Brain keeps them alive. It processes your meeting transcripts every evening, connects today's discussions to last month's threads, tracks your commitments, and briefs you every morning on what matters.

It runs on two daily rituals:

- **`/wind-down`** (evening, ~10 min): Process today's meetings, update living documents, review and approve changes
- **`/wake-up`** (morning, ~2 min read): Get oriented on today's meetings with relationship context, open threads, and accountability checks

Over time, the system learns your preferences, tracks long-running topics across weeks and months, and surfaces dormant ideas that deserve another look.

## How it works

Brain is a folder of markdown files and a set of command prompts that tell Claude Code how to process them. No database, no server, no dependencies. Just files and git.

```
brain/
  config.md            # Your identity, data sources, paths
  preferences.md       # Learned rules (sensitivity, tracking, domain knowledge)
  health.md            # System metrics and run history
  handoff.md           # Rolling daily log (newest at top)
  commitments.md       # Action items tracker
  threads/             # Topic files that evolve over time
  people/              # Relationship context files
  archive/
    meetings/          # Raw transcripts and summaries by date
    contexts/          # Archived threads/people from previous jobs
  commands/
    setup.md           # First-run configuration
    wind-down.md       # Evening processing ritual
    wake-up.md         # Morning briefing ritual
```

### Living documents

- **Threads**: Long-running topics tracked across meetings. Not projects with rigid hierarchy — flat files that can cross-link. Topics go active, dormant, or resolved over time. Dormant threads get resurfaced when they connect to new discussions.
- **People**: Relationship context files for recurring collaborators. What you last discussed, open items between you, their current focus. Useful for meeting prep.
- **Commitments**: Action items with real accountability. Only meaningful deliverables — not "we should grab coffee sometime."
- **Handoff**: A rolling daily log. Each evening's wind-down adds an entry at the top. Each morning's wake-up reads it to get oriented. Quarterly, old entries get archived with a compressed summary.

### The feedback loop

The system learns from your corrections. Every time you fix something during the wind-down review, the underlying rule gets captured in `preferences.md` so it doesn't happen again. Over time, the system gets better at:
- Knowing what's worth tracking vs. noise
- Respecting sensitivity boundaries
- Understanding your domain terminology
- Matching your style preferences

## Quick start

### Prerequisites
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- A meeting recording tool ([Granola](https://granola.ai), [Otter.ai](https://otter.ai), Zoom transcripts, [Fireflies](https://fireflies.ai), or even just copy-pasted notes)

### Setup

1. Clone this repo:
   ```bash
   git clone https://github.com/YOUR_USERNAME/brain.git ~/brain
   ```

2. Open Claude Code and run the setup command:
   ```
   Read ~/brain/commands/setup.md and follow its instructions
   ```

3. Answer a few questions (name, meeting tool, calendar source). Takes < 3 minutes.

4. Run your first wind-down after today's meetings:
   ```
   Read ~/brain/commands/wind-down.md and follow its instructions
   ```

5. Run wake-up tomorrow morning:
   ```
   Read ~/brain/commands/wake-up.md and follow its instructions
   ```

## Supported meeting sources

| Source | Auto-extract | Speaker labels | Notes |
|--------|-------------|----------------|-------|
| Granola | Yes (local cache) | No | Transcripts only persist ~1 day in cache |
| Otter.ai | Yes (file export) | Yes | Configure auto-export in Otter settings |
| Fireflies | Yes (file export) | Yes | Has its own AI summaries for cross-reference |
| Zoom | Manual upload | Yes | Download .vtt from Zoom after meeting |
| Manual paste | During wind-down | Varies | Works with any text source |

## Key design decisions

**Threads, not projects.** Flat topic files instead of hierarchical project trees. Topics can overlap via cross-linking. Avoids the "what level is this project?" taxonomy trap.

**Confidence levels.** Every decision the agent makes is tagged with a confidence level (high/medium/low). High-confidence decisions get a quick scan. Low-confidence decisions get your explicit input. This focuses your review time where it matters most.

**Preferences as learning.** `preferences.md` accumulates rules through use, not upfront configuration. The review process is the training interface. Corrections become durable rules.

**Health monitoring.** The system tracks its own metrics (thread count, decision confidence ratios, review engagement) and flags when thresholds are crossed. Thresholds are tunable through the same feedback loop as everything else.

**Portable by design.** Everything is markdown in a git repo. Switch jobs? Run `/setup` again — it archives your old context and starts fresh while preserving structural knowledge. Clone to a new machine? You're operational in 3 minutes.

## Job transitions

When you start a new role:
1. Run the setup command again
2. Choose "Starting a new job/role"
3. Your threads and people get archived (not deleted)
4. Domain knowledge in preferences gets marked as potentially stale
5. Structural preferences (how to process, what to track) carry over
6. The system re-learns your new context through daily use

## Philosophy

Brain is a cognitive exoskeleton, not an AI replacement for thinking. It handles the mechanical work of connecting dots across meetings so you can focus on the strategic work of deciding what matters.

The system is opinionated but transparent. It makes decisions and explains its reasoning. When it's wrong, your correction makes it permanently smarter. The goal is a tool that feels like a really good chief of staff who's been working with you for years.

## License

MIT
