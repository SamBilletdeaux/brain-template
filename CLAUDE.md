# Brain Template (Public)

A personal knowledge system that processes meeting transcripts into living documents. Runs entirely on Claude Code with markdown files and git.

## Commands (in .claude/commands/)
- `/setup` - First-time configuration
- `/wind-down` - Evening processing ritual
- `/wake-up` - Morning briefing

## Project Structure
```
brain/
├── .claude/commands/   # Slash command prompts
├── config.md           # User identity and data sources
├── preferences.md      # Learned rules from corrections
├── handoff.md          # Rolling daily log
├── commitments.md      # Action items with accountability
├── health.md           # System metrics
├── threads/            # Topic files
├── people/             # Relationship context
└── archive/            # Old meetings and contexts
```

## Development Notes
- This is the PUBLIC template repo
- Personal usage happens in ~/brain (private repo)
- Changes here get pulled into private repos via `git pull template master`
- Keep template files clean of personal data

## Session Management
- `claude --continue` - resume last session
- `claude --resume` - pick from recent sessions
- `/capture` - extract stable facts from conversation into CLAUDE.md

## Design Principles
- Threads, not projects (flat > hierarchical)
- Confidence tagging on all AI decisions
- Learning through corrections, not upfront config
- Portable by design (just markdown + git)
