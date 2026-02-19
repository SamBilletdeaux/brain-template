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
| `/doctor` | System health check — validates config, links, staleness |
| `/search` | Full-text search across all brain files and relationships |
| `/weekly-review` | Weekly reflection — threads, commitments, trends |

## Helper Scripts (in scripts/)

| Script | Purpose |
|--------|---------|
| `pick-files.sh` | Native macOS file picker, returns selected paths |
| `extract-granola.sh` | Parse Granola cache, list meetings by date |
| `validate-config.sh` | Validate config.md structure and paths |
| `update-health.sh` | Update health.md metrics (called by wind-down) |
| `archive.sh` | Archive old handoff entries, completed commitments |
| `snapshot-transcripts.sh` | Snapshot Granola transcripts to inbox (safety net) |
| `capture-note.sh` | Quick-capture a thought to inbox for next wind-down |
| `install-daemon.sh` | Install transcript snapshotter as launchd service |
| `uninstall-daemon.sh` | Remove transcript snapshotter service |
| `indexer.py` | Build/update SQLite search index from markdown files |
| `query-graph.py` | Query entity relationships (connections, timelines) |
| `schema.sql` | SQLite schema for the search index |
| `install-hooks.sh` | Install git post-commit hook for auto-indexing |
| `brain-server.sh` | Start/stop/status for the local web UI |
| `generate-prep.py` | Auto-generate meeting prep packets from calendar |
| `generate-followups.py` | Draft follow-up messages for commitments |
| `background-processor.py` | Process inbox transcripts into drafts |
| `notify.sh` | Send macOS notifications (direct or scheduled checks) |
| `install-notifications.sh` | Install notification launchd agents |
| `uninstall-notifications.sh` | Remove notification agents |

## Web UI (in web/)

A local web app for browsing your brain in a browser. Not deployed — runs on `localhost:3141`.

```bash
./scripts/brain-server.sh start ~/brain    # Start and open browser
./scripts/brain-server.sh stop             # Stop the server
./scripts/brain-server.sh status           # Check if running
```

Pages: Dashboard (`/`), Timeline (`/timeline`), Search (`/search`), Thread detail (`/thread/:name`), Person detail (`/person/:name`)

### extract-granola.sh usage:
```bash
./scripts/extract-granola.sh              # Today's meetings
./scripts/extract-granola.sh 2026-02-15   # Specific date
./scripts/extract-granola.sh --list-dates # Show available dates
```

### archive.sh usage:
```bash
./scripts/archive.sh ~/brain              # Run archival
./scripts/archive.sh ~/brain --dry-run    # Preview without changes
```

### capture-note.sh usage:
```bash
./scripts/capture-note.sh "quick thought about the meeting"  # inline
./scripts/capture-note.sh                                     # opens editor
# Tip: alias note="~/brain-template/scripts/capture-note.sh"
```

## Project Structure
```
brain/
├── .claude/commands/   # Slash command prompts
├── scripts/            # Helper scripts
├── inbox/              # Raw inputs (gitignored)
│   ├── granola/        # Auto-snapshotted transcripts
│   ├── notes/          # Quick captures
│   ├── files/          # Manual uploads
│   └── .processed/     # Processed item markers
├── web/                # Local web UI (Express + SQLite)
├── .brain.db           # SQLite search index (gitignored, rebuildable)
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
- **Granola transcripts missing?** Cache only holds ~1 day — install the daemon (`./scripts/install-daemon.sh`) to auto-snapshot every 30 min

## Design Principles
- Threads, not projects (flat > hierarchical)
- Confidence tagging on all AI decisions (🟢/🟡/🔴)
- Learning through corrections, not upfront config
- Portable by design (just markdown + git)
- Two-repo separation: code is public, data is private
