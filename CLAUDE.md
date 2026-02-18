# Brain Template (Public)

A personal knowledge system that processes meeting transcripts into living documents. Runs entirely on Claude Code with markdown files and git.

## Commands (in .claude/commands/)

| Command | Purpose |
|---------|---------|
| `/setup` | First-time configuration (identity, data sources) |
| `/wind-down` | Evening processing ritual (~5-10 min) |
| `/wake-up` | Morning briefing (~2 min read) |
| `/capture` | Extract stable facts from conversation to CLAUDE.md |
| `/pick-files` | Open native macOS file picker |
| `/sync-template` | Pull latest template updates into private brain |

## Helper Scripts (in scripts/)

| Script | Purpose |
|--------|---------|
| `pick-files.sh` | Native macOS file picker, returns selected paths |
| `extract-granola.sh` | Parse Granola cache, list meetings by date |

### extract-granola.sh usage:
```bash
./scripts/extract-granola.sh              # Today's meetings
./scripts/extract-granola.sh 2026-02-15   # Specific date
./scripts/extract-granola.sh --list-dates # Show available dates
```

## Project Structure
```
brain/
├── .claude/commands/   # Slash command prompts
├── scripts/            # Helper scripts
├── config.md           # User identity and data sources
├── preferences.md      # Learned rules from corrections
├── handoff.md          # Rolling daily log
├── commitments.md      # Action items with accountability
├── health.md           # System metrics
├── threads/            # Topic files
├── people/             # Relationship context
└── archive/            # Old meetings and contexts
```

## Two-Repo Workflow

This template is designed for a two-repo setup:

| Repo | Visibility | Purpose |
|------|------------|---------|
| `brain-template` | Public | The "code" — commands, scripts, structure |
| `brain` | Private | Your personal data — meetings, threads, people |

**Workflow:**
1. Make template improvements in `brain-template`
2. Push to public repo
3. Pull into private `brain` with `/sync-template`

## Session Management
- `claude --continue` — resume last session
- `claude --resume` — pick from recent sessions
- `/capture` — extract stable facts at end of session

## Wind-Down Process Notes

During `/wind-down`:
- Say **"pick files"** to open a native file picker for additional transcripts
- Review proposed changes by confidence level (🟢/🟡/🔴)
- Corrections become durable rules in preferences.md
- Say **"commit"** when ready to write all changes

## Known Gotchas
- **Slash commands not working?** Restart the Claude Code session after adding new commands to `.claude/commands/`
- **First template sync fails?** Use `git merge template/master --allow-unrelated-histories`
- **Large Zoom transcripts?** May exceed token limits — read in chunks or preprocess
- **Granola transcripts missing?** Cache only holds ~1 day — run `/wind-down` same day

## Design Principles
- Threads, not projects (flat > hierarchical)
- Confidence tagging on all AI decisions (🟢/🟡/🔴)
- Learning through corrections, not upfront config
- Portable by design (just markdown + git)
- Two-repo separation: code is public, data is private
