# Brain System Roadmap

A phased project plan to evolve brain-template from a CLI batch processor into an always-on personal knowledge system.

**Principle**: Each phase is independently valuable. Ship each one before starting the next.

**Tech stack**: Node.js (v23), SQLite (index), Python (data scripts), launchd (background services), markdown + git (source of truth).

---

## Phase 1: Harden the Foundation

> Goal: Make what exists actually reliable. Fix bugs, add validation, make the system trustworthy.

### 1.1 Fix extract-granola.sh null safety
- `google_calendar_event` can be null — script crashes
- Add null checks for `cal.get('start')`, `cal.get('attendees')`
- Already hit this bug live during /wake-up
- **Files**: `scripts/extract-granola.sh`

### 1.2 Add config validation
- New script: `scripts/validate-config.sh`
- Check required fields exist (Name, Role, at least one data source)
- Check referenced paths exist (brain root, archive, cache paths)
- Check data source types are recognized
- Run at start of /wind-down and /wake-up — fail loud, not silent
- **Files**: `scripts/validate-config.sh`, `.claude/commands/wind-down.md`, `.claude/commands/wake-up.md`

### 1.3 Implement health metrics computation
- wind-down Phase 6 references metrics but doesn't implement them
- Build a `scripts/update-health.sh` that takes parameters and updates health.md
- Compute: meetings processed, decisions by confidence level, corrections, thread/people counts, days since last run
- **Files**: `scripts/update-health.sh`, `health.md`

### 1.4 Build /doctor command
- New command: `.claude/commands/doctor.md`
- Validates config.md structure
- Checks all `[[wiki-links]]` resolve to real files
- Flags stale commitments (>5 days per threshold)
- Flags dormant threads (>30 days)
- Reports file sizes and growth trends
- Checks Granola cache exists and is readable
- Checks git status (uncommitted changes, unpushed commits)
- **Files**: `.claude/commands/doctor.md`

### 1.5 Make wind-down idempotent
- Running /wind-down twice on the same day should update the existing entry, not duplicate
- Add date check in handoff.md — if today's entry exists, update it
- Same for health.md run history
- **Files**: `.claude/commands/wind-down.md`

### 1.6 Implement archival
- New script: `scripts/archive.sh`
- Moves handoff entries older than 90 days to `archive/handoffs/YYYY-QN.md` with compressed summary
- Moves completed commitments older than 30 days to `archive/commitments/YYYY.md`
- Flags dormant threads for archival (human confirms)
- Run manually or suggest during /doctor
- **Files**: `scripts/archive.sh`, `.claude/commands/doctor.md`

---

## Phase 2: Never Lose Data

> Goal: Eliminate the "forgot to run wind-down and lost today's transcripts" failure mode. Build an automatic safety net.

### 2.1 Transcript snapshotter daemon
- `scripts/snapshot-transcripts.sh` — copies Granola cache transcripts to `inbox/granola/YYYY-MM-DD/`
- Only copies new documents (compares against last snapshot)
- Extracts: document ID, title, created_at, transcript text, attendees, calendar event
- Stores as individual JSON files (one per meeting) for easy processing
- **Files**: `scripts/snapshot-transcripts.sh`

### 2.2 launchd service for automatic snapshots
- `com.brain.transcript-snapshotter.plist` — runs every 30 minutes
- Watches Granola cache, snapshots new transcripts
- Logs to `~/brain/logs/snapshotter.log`
- Install/uninstall via `scripts/install-daemon.sh` and `scripts/uninstall-daemon.sh`
- **Files**: `scripts/com.brain.transcript-snapshotter.plist`, `scripts/install-daemon.sh`, `scripts/uninstall-daemon.sh`

### 2.3 Inbox directory pattern
- New directory: `inbox/` (gitignored — raw data, not committed)
- Subdirectories: `inbox/granola/`, `inbox/files/`, `inbox/voice/`, `inbox/web/`
- wind-down reads from inbox instead of directly from Granola cache
- Inbox is the universal input layer — any source just drops files here
- **Files**: `.gitignore`, `.claude/commands/wind-down.md`

### 2.4 Update wind-down to read from inbox
- Phase 0 checks inbox first, falls back to live Granola cache
- Processes all unprocessed items in inbox (not just today)
- Marks items as processed after successful wind-down (moves to `inbox/.processed/`)
- Enables catch-up: missed Monday? Process Monday's transcripts on Tuesday
- **Files**: `.claude/commands/wind-down.md`

### 2.5 Quick-capture CLI helper
- `scripts/capture-note.sh "some thought about the AISP meeting"`
- Drops a timestamped markdown file into `inbox/notes/`
- Picked up by next wind-down and routed to appropriate thread
- Could be aliased in .zshrc: `alias note="~/brain-template/scripts/capture-note.sh"`
- **Files**: `scripts/capture-note.sh`

---

## Phase 3: Make It Searchable

> Goal: Build a SQLite index alongside the markdown files. Full-text search across everything. The markdown stays as source of truth; SQLite is the fast lookup layer.

### 3.1 SQLite schema design
- Tables: `documents` (all markdown files), `entities` (people, threads, meetings, commitments), `relationships` (edges between entities), `search_index` (FTS5 virtual table)
- `documents`: id, path, type (thread/person/handoff/commitment/meeting), content, created_at, updated_at, hash (for change detection)
- `entities`: id, name, type, document_id (source file), metadata (JSON)
- `relationships`: source_id, target_id, type (mentioned_in, discussed_at, committed_to, related_to), context, created_at
- FTS5 index on document content + entity names
- **Files**: `scripts/schema.sql`

### 3.2 Indexer script
- `scripts/index-brain.sh` — scans all markdown files, extracts entities, builds relationships, updates FTS index
- Incremental: only re-indexes files whose hash changed since last run
- Extracts `[[wiki-links]]` as relationships
- Extracts `@mentions` as people references
- Extracts dates, commitment statuses, thread statuses
- Store DB at `~/brain/.brain.db` (gitignored)
- **Files**: `scripts/index-brain.sh`, `scripts/indexer.py`

### 3.3 Search command
- New command: `.claude/commands/search.md`
- Takes a natural language query, translates to FTS5 + graph queries
- Returns: matching documents with snippets, related entities, timeline of mentions
- Example: "What did I discuss with Wei about content agent?" → searches FTS for "Wei" + "content agent", returns matching handoff entries, thread updates, meeting summaries, sorted by date
- **Files**: `.claude/commands/search.md`

### 3.4 Auto-index hook
- After every git commit in the brain repo, re-index changed files
- Git post-commit hook: `.git/hooks/post-commit`
- Or: run indexer at start of /wake-up and end of /wind-down
- **Files**: `scripts/install-hooks.sh`

### 3.5 Relationship graph queries
- `scripts/query-graph.py` — CLI tool for graph traversal
- "Who have I discussed AISP with?" → traverse relationships from AISP thread to people entities
- "What threads connect to this person?" → reverse lookup
- "What's the decision history for X?" → chronological traversal through meeting summaries
- Used by /wake-up for meeting prep and by /search for context
- **Files**: `scripts/query-graph.py`

---

## Phase 4: Web UI

> Goal: A local web app that makes the brain browsable, searchable, and reviewable without opening a terminal. Not a deployed app — runs on localhost.

**Tech**: Node.js + Express + SQLite + htmx (minimal frontend, no build step)

### 4.1 Project scaffolding
- `web/` directory in brain-template
- `web/server.js` — Express server, reads from brain directory and SQLite index
- `web/package.json` — minimal dependencies (express, better-sqlite3, marked)
- `web/views/` — HTML templates (server-rendered, not SPA)
- Start with: `node web/server.js --brain ~/brain`
- **Files**: `web/server.js`, `web/package.json`, `web/views/layout.html`

### 4.2 Dashboard page
- `/` — overview of brain state
- Active threads with last-updated dates
- Open commitments (grouped: active, stale, waiting)
- Recent handoff entries (last 3 days)
- People files with last-contact dates
- Health metrics summary
- Quick links to everything
- **Files**: `web/views/dashboard.html`, `web/routes/dashboard.js`

### 4.3 Timeline view
- `/timeline` — chronological view of all activity
- Filter by: thread, person, date range, entity type
- Each entry shows: date, source meeting, what changed, confidence level
- Clickable links to full thread/person/meeting files
- "Show me the arc of Content Agent from inception to now"
- **Files**: `web/views/timeline.html`, `web/routes/timeline.js`

### 4.4 Search page
- `/search` — full-text search with filters
- Search box with instant results (htmx for live search)
- Results grouped by type: threads, people, meetings, commitments
- Snippets with highlighted matches
- Powered by SQLite FTS5 index from Phase 3
- **Files**: `web/views/search.html`, `web/routes/search.js`

### 4.5 Entity detail pages
- `/thread/:name` — full thread view with timeline, related people, commitments
- `/person/:name` — full person view with meeting history, shared threads, open items
- `/meeting/:date/:id` — meeting summary with transcript link, attendees, outcomes
- `/commitment/:id` — commitment detail with history and status
- Render markdown to HTML (using `marked`)
- **Files**: `web/views/thread.html`, `web/views/person.html`, `web/routes/entities.js`

### 4.6 Review interface
- `/review` — the wind-down review flow as a web UI
- Shows queued changes from inbox processing (Phase 2)
- Each change has: proposed update, confidence level, approve/edit/reject buttons
- Corrections captured and written to preferences.md
- Replaces the CLI back-and-forth of current /wind-down Phase 4
- **Files**: `web/views/review.html`, `web/routes/review.js`

### 4.7 Start/stop script
- `scripts/brain-server.sh start|stop|status`
- Optional: launchd plist to auto-start on login
- Opens browser to `http://localhost:3141` (pi — why not)
- **Files**: `scripts/brain-server.sh`

---

## Phase 5: Proactive Operations

> Goal: The system doesn't just wait for you to ask. It watches, prepares, and nudges. This is where the 10x happens.

### 5.1 Meeting prep auto-generation
- 15 minutes before each meeting (based on calendar), auto-generate a prep packet:
  - Attendee context (from people files)
  - Relevant thread summaries
  - Open commitments involving attendees
  - Last meeting notes with these people
  - Suggested talking points
- Store in `inbox/prep/YYYY-MM-DD-meeting-title.md`
- Surface in web UI dashboard
- Requires: Google Calendar integration (see 5.2) or Granola calendar data
- **Files**: `scripts/generate-prep.py`, `web/routes/prep.js`

### 5.2 Google Calendar integration
- OAuth2 flow for Google Calendar read access
- `scripts/calendar-sync.sh` — fetches next 24 hours of events
- Stores in `inbox/calendar/today.json`
- Used by meeting prep generator and /wake-up
- Replaces fragile Granola cache calendar parsing
- **Files**: `scripts/calendar-sync.sh`, `scripts/google-auth.py`, `web/routes/auth.js`

### 5.3 Continuous background processor
- Upgrade the Phase 2 snapshotter into a full processor
- When new transcript lands in inbox: auto-generate draft summary, extract entities, queue for review
- Uses Claude API (not Claude Code) for processing — faster, scriptable
- Results land in `inbox/drafts/` as proposed changes
- Web UI review interface (Phase 4.6) shows these drafts
- Wind-down becomes: "review what the system already prepared" instead of "wait while it processes"
- **Files**: `scripts/background-processor.py`

### 5.4 Notification system
- `scripts/notify.sh` — sends a macOS notification (osascript)
- Triggers: meeting prep ready, stale commitment detected, wind-down reminder (8pm if not run)
- Optional: Slack webhook for delivery to phone
- **Files**: `scripts/notify.sh`

### 5.5 Weekly review auto-generation
- New command: `.claude/commands/weekly-review.md`
- Auto-generates every Friday (or on demand):
  - Threads that moved forward this week
  - Threads that stalled
  - New threads created
  - Commitments completed / added / stale
  - People you talked to most / least
  - Relationship maintenance suggestions ("haven't spoken to X in 3 weeks")
  - Energy/load trends from health.md
- **Files**: `.claude/commands/weekly-review.md`, `scripts/generate-weekly.py`

### 5.6 Follow-up draft generation
- After wind-down identifies a commitment like "send X to Y":
  - Auto-draft the message (email body, Slack message, etc.)
  - Store in `inbox/drafts/follow-ups/`
  - Surface in web UI: "You committed to sending Wei the AISP analysis. Here's a draft."
  - User reviews, edits, sends manually (system never sends on its own)
- **Files**: `scripts/generate-followups.py`, `web/views/followups.html`

---

## Phase 6: External Integrations

> Goal: Connect the brain to where work actually happens. Each integration is optional and independently useful.

### 6.1 Slack bot
- Brain bot in Slack workspace
- Commands: `/brain search [query]`, `/brain prep [meeting]`, `/brain status`
- Passive: watches starred messages, drops them in inbox
- Morning briefing delivered as a DM at configured time
- Meeting prep delivered 15min before each meeting
- **Tech**: Node.js Slack SDK, runs as part of web server
- **Files**: `web/integrations/slack.js`

### 6.2 Email integration
- Forward-to-brain address (e.g., using Cloudflare Email Workers or a simple IMAP watcher)
- Forward an email → drops in inbox as markdown
- Weekly digest email: summary of brain activity
- Follow-up drafts openable in email client
- **Files**: `scripts/email-watcher.py` or `web/integrations/email.js`

### 6.3 Linear/Jira sync
- Commitments with `@linear:ISSUE-123` tag sync bidirectionally
- When a ticket moves to "Done" in Linear, commitment auto-completes
- When a new commitment is created in wind-down, optionally create a Linear ticket
- **Files**: `web/integrations/linear.js`

### 6.4 Browser extension (stretch)
- "Add to brain" button on any web page
- Captures: URL, title, selected text, user note
- Drops in inbox/web/ for next wind-down processing
- Simple Chrome extension, sends to local web server
- **Files**: `extension/` directory

---

## Implementation Sequence

```
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4 ──→ Phase 5 ──→ Phase 6
 harden      safety      search      web UI      proactive   integrate
```

### Dependencies
- Phase 2 (inbox) is needed by Phase 4.6 (review UI) and Phase 5.3 (background processor)
- Phase 3 (SQLite) is needed by Phase 4.4 (search page) and Phase 5.1 (meeting prep)
- Phase 4 (web UI) is needed by Phase 5 (proactive ops surface through the UI)
- Phase 5.2 (calendar) is needed by Phase 5.1 (meeting prep timing)
- Phase 6 items are all independent of each other

### What stays in brain-template (public)
- All scripts, commands, web UI code, schema, extension
- The *system*, not the data

### What stays in brain (private)
- inbox/, .brain.db, logs/, credentials, actual content files
- The *data*, not the system

---

## Open Questions

1. **Claude API vs Claude Code for background processing?** Phase 5.3 suggests Claude API for scriptable processing. This means an API key and cost. Alternative: keep everything in Claude Code sessions but make them faster.

2. **Auth for web UI?** It's localhost-only, but should there be a password? Or is "only accessible on your machine" sufficient?

3. **How much should the system auto-draft?** Follow-up emails, meeting prep, weekly reviews — should these be opt-in per type, or all-on by default?

4. **Notification channel?** macOS notifications, Slack DMs, email, or all three? Start with one and expand?

5. **Should the web UI replace wind-down/wake-up?** Or complement them? Could wind-down become "open the review page" instead of a CLI session.
