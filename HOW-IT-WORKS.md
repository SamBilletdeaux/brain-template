# How It Works

A plain-English guide to every component in the brain system — what it is, why it exists, and how the pieces fit together.

Updated as the system evolves.

---

## The Big Picture

You have meetings all day. Valuable decisions, context, and commitments come out of those meetings. But within hours, the details start fading. This system captures that knowledge automatically and turns it into a living, searchable record.

The system has two modes:
- **Wind-down** (evening): Process today's meetings, update your knowledge files, track commitments
- **Wake-up** (morning): Get briefed on what matters today based on everything the system knows

Everything is stored as plain markdown files in a git repo — human-readable, portable, and version-controlled.

---

## Core Files

### config.md
**What**: Your identity and preferences for how the system finds your meetings.
**Why**: Every command reads this first. It tells the system your name, what tools you use for meeting transcripts (Granola, Zoom, etc.), and where to find data. Without this, nothing else works.

### preferences.md
**What**: A growing list of rules the system has learned from your corrections.
**Why**: Instead of configuring everything upfront, the system makes its best guess and you correct it. Each correction becomes a permanent rule. For example: "Wade in transcripts always means Wei" or "don't track casual coffee chats as commitments." Over time, the system gets better at matching your judgment.

### handoff.md
**What**: A daily log — one entry per evening, newest at top.
**Why**: This is how context transfers from yesterday-you to today-you. The morning briefing reads this to know what happened recently. Think of it as a journal that your AI assistant writes for you.

### commitments.md
**What**: Action items with owners and sources.
**Why**: Meetings generate commitments. Most people forget half of them by the next day. This file tracks what you owe people and what they owe you, with links back to the meeting where each item originated.

### health.md
**What**: System metrics — how many meetings processed, how many AI decisions were corrected, trend data.
**Why**: Keeps the system honest. If the AI is making too many wrong calls, or if you haven't run wind-down in a week, health.md surfaces that. It's the system's self-awareness mechanism.

### threads/
**What**: A folder of topic files. Each file tracks one ongoing topic across multiple meetings.
**Why**: Conversations about a topic are scattered across dozens of meetings over months. Thread files stitch those fragments into a single narrative. Instead of "what did we say about the AI Topic Map?", you open one file and see the full arc.

### people/
**What**: A folder of relationship context files. One per person you work with regularly.
**Why**: Before a meeting with someone, you want to know: what did we last discuss? Are there open items between us? What are they focused on right now? People files hold that context so you walk into meetings prepared.

### archive/
**What**: Storage for processed meeting transcripts, old handoff entries, and completed commitments.
**Why**: Raw data needs to live somewhere after processing. Archiving keeps the active files lean while preserving the full record for reference.

---

## Commands

These are prompts that tell Claude Code what to do. You run them by typing the command name.

### /setup
**What**: First-time configuration wizard.
**Why**: Walks you through setting your name, role, and connecting your meeting transcript source. Only needs to run once (or again when changing jobs).

### /wind-down
**What**: The evening processing ritual. Reads your meeting transcripts, proposes updates to threads/people/commitments, and asks for your review before writing anything.
**Why**: This is the core loop. Meetings happen → wind-down captures the knowledge → files get updated → git commits the changes. The review step is critical: the AI shows you what it thinks happened and you correct anything wrong. Those corrections make it smarter next time.

### /wake-up
**What**: A 2-minute morning briefing.
**Why**: Reads your calendar, handoff, commitments, and relevant threads to tell you: here's what happened yesterday, here's what's coming today, here's what you should know before your first meeting.

### /doctor
**What**: A health check that validates the system's integrity.
**Why**: Like a car diagnostic. Checks that config is valid, that file cross-references aren't broken, that no commitments have gone stale, and that threads aren't being neglected. Run it when something feels off, or periodically as maintenance.

### /capture
**What**: Extracts stable facts from the current conversation into CLAUDE.md.
**Why**: Sometimes useful context comes up in a chat session that should persist. This saves it so future sessions have that knowledge.

### /pick-files
**What**: Opens a native macOS file picker.
**Why**: During wind-down, you might have extra transcripts or documents to process. Instead of typing file paths, say "pick files" and select them in Finder.

### /sync-template
**What**: Pulls the latest template updates from the public repo into your private brain.
**Why**: The system code (commands, scripts) lives in a public repo so it can be shared and improved. Your personal data lives in a private repo. This command merges improvements without touching your data.

---

## Scripts

These are the actual code that does things. Commands tell Claude what to do; scripts are the tools Claude (or automated services) use to do it.

### extract-granola.sh
**What**: Reads the Granola app's local cache and extracts meeting data — titles, times, attendees, transcript text.
**Why**: Granola stores meeting recordings in a JSON cache file on your Mac. This script is the bridge between Granola's format and the brain system. It's how the system knows what meetings you had today.

### validate-config.sh
**What**: Checks that config.md is properly filled out — name exists, data sources are configured, paths point to real directories.
**Why**: If config is wrong, every other command fails in confusing ways. This catches problems early with clear error messages instead of letting them cascade.

### update-health.sh
**What**: Takes metrics from a wind-down session (meetings processed, decisions made, corrections received) and writes them to health.md.
**Why**: Wind-down needs a reliable way to update the health dashboard. This script handles both first-time writes and updating an existing entry for the same day (so running wind-down twice doesn't create duplicates).

### archive.sh
**What**: Moves old data to archive folders — handoff entries older than 90 days, completed commitments older than 30 days.
**Why**: Without this, your active files grow forever and become slow to read. Archiving keeps the working set small while preserving everything for reference. Run with `--dry-run` to preview before committing.

### snapshot-transcripts.sh
**What**: Copies meeting transcripts from Granola's cache into your brain's inbox as individual JSON files.
**Why**: **This is the safety net.** Granola only keeps transcripts in its cache for about 1 day. If you forget to run wind-down one evening, those transcripts are gone forever. This script preserves them before they expire. It only copies new meetings (safe to run repeatedly).

### capture-note.sh
**What**: Saves a quick thought as a timestamped file in the inbox.
**Why**: Sometimes you have a thought between meetings that should be captured — "we should revisit the clustering approach" or "Katie mentioned she's blocked on Pages." This drops it into the inbox so the next wind-down can route it to the right thread. Much faster than opening a file and writing it yourself.

### install-daemon.sh / uninstall-daemon.sh
**What**: Installs (or removes) the transcript snapshotter as a background service that runs every 30 minutes.
**Why**: You shouldn't have to remember to run the snapshotter manually. The daemon does it automatically — every 30 minutes it checks if Granola has new meetings and saves them. Install once, forget about it, never lose a transcript.

### pick-files.sh
**What**: Opens a native macOS Finder window for selecting files.
**Why**: When you need to feed extra files into wind-down (a Zoom transcript, a Google Doc export, etc.), this gives you a familiar file picker instead of having to type paths.

---

## The Inbox

**What**: A directory (`inbox/`) that acts as the system's universal input tray. Gitignored — raw data stays out of version control.

**Why**: Different inputs arrive at different times and from different sources. The inbox gives them all one place to land:

| Subdirectory | What goes here | How it gets here |
|-------------|---------------|-----------------|
| `inbox/granola/` | Snapshotted meeting transcripts | Automatically, via the daemon (every 30 min) |
| `inbox/notes/` | Quick-capture thoughts | You, via `capture-note.sh` |
| `inbox/files/` | Manual uploads (Zoom transcripts, docs, etc.) | You, via file picker or manual copy |
| `inbox/.processed/` | Markers for items already processed | Automatically, after wind-down commits |

Wind-down reads from the inbox first. If nothing is there for today, it falls back to reading Granola's cache directly. The inbox also enables **catch-up processing** — if you miss Monday's wind-down, the daemon already saved Monday's transcripts, and Tuesday's wind-down will find and process them.

---

## The Search Index

**What**: A SQLite database (`.brain.db`) that mirrors everything in your markdown files but makes it searchable and queryable instantly.

**Why**: Markdown files are great for reading and editing, but terrible for answering questions like "what did I discuss with Wei about the content agent last month?" Searching across 20+ files manually is painful. The search index lets you ask questions like that and get answers in seconds.

**How it works**: The indexer reads every markdown file and extracts three things:
1. **Documents** — the files themselves, with content hashes so it only re-processes what changed
2. **Entities** — the important things: people, threads, meetings, commitments. Each one becomes a searchable record.
3. **Relationships** — the connections between entities. "This meeting discussed this thread." "This person is connected to this thread." These form a graph you can traverse.

The search uses FTS5 (SQLite's full-text search engine), which supports word stemming — so searching "clustering" also finds "clustered" and "clusters."

**Important**: The markdown files are always the source of truth. The database is derived and can be rebuilt from scratch at any time. If it ever gets corrupted, just delete `.brain.db` and re-run the indexer.

### indexer.py
**What**: The script that builds and updates the search index.
**Why**: Reads all your markdown files, extracts entities and relationships, and populates the database. Runs incrementally — if only one file changed, it only re-indexes that file. Takes less than a second for typical brains.

### query-graph.py
**What**: A command-line tool for querying the relationship graph directly.
**Why**: Sometimes you want to ask structural questions: "what threads is Simone connected to?" or "which meetings discussed AISP?" This tool traverses the graph and gives you answers without reading files manually.

Commands:
- `query-graph.py ~/brain stats` — overview of your brain's size and connectivity
- `query-graph.py ~/brain thread "AISP"` — everything about a thread: related threads, meetings, people
- `query-graph.py ~/brain person "Simone"` — everything about a person: their threads, meetings, context
- `query-graph.py ~/brain connections "Content Agent"` — all entities connected to something
- `query-graph.py ~/brain timeline "AISP"` — chronological mentions across all files

### schema.sql
**What**: The database structure definition.
**Why**: Defines the tables, indexes, and full-text search configuration. If you ever need to rebuild the database, this is the blueprint.

### /search
**What**: A Claude Code command that lets you ask questions about your brain in natural language.
**Why**: Instead of remembering SQL queries or graph commands, you just ask: "What did I discuss with Wei about the content agent?" The search command translates your question into database queries, finds the relevant files, and presents a clear answer with sources.

### install-hooks.sh
**What**: Installs a git hook that automatically re-indexes your brain after every commit.
**Why**: Without this, the search index can get out of date. With the hook installed, every time wind-down commits changes, the index updates automatically in the background. You never have to think about it.

---

## Proactive Operations

The system doesn't just wait for you to ask — it watches, prepares, and nudges.

### Meeting Prep (generate-prep.py)
**What**: Before your meetings, auto-generates a prep packet with attendee context, relevant threads, open commitments, and recent handoff mentions.
**Why**: Walking into a meeting prepared means better outcomes. This pulls everything you need from your brain files in seconds instead of you having to open and read multiple files.
**How**: Reads calendar data from Granola, matches attendees to people files (by name, email, or even parsing the meeting title), finds threads that mention those people, and checks for related commitments. Output goes to `inbox/prep/`.

### Notifications (notify.sh)
**What**: macOS notifications for wind-down reminders (8pm), stale commitments (9am), and meeting prep readiness (8am/12pm).
**Why**: The system should nudge you, not the other way around. If you haven't processed today's meetings by evening, you get a reminder. If a commitment is going stale, you get a heads-up.
**How**: Shell script using `osascript` for native macOS notifications. Three launchd agents run on schedule. Install with `install-notifications.sh`.

### Background Processor (background-processor.py)
**What**: Watches the inbox for new transcript snapshots and pre-indexes entity extractions (people, threads, action patterns, decisions) into draft files.
**Why**: Pre-digests transcripts as they arrive so wind-down has a head start on entity matching. All actual AI analysis happens in Claude Code during /wind-down — this script handles the mechanical pattern-matching.
**How**: Scans `inbox/granola/` recursively, runs rule-based extraction (people matching, thread matching, action/decision regex), writes drafts to `inbox/drafts/`. Run with `--once` or in continuous watch mode. No API key required.

### Follow-Up Drafts (generate-followups.py)
**What**: Detects commitments that look like "send X to Y" or "share X with Y" and generates draft message skeletons with context.
**Why**: The hardest part of following up is starting the message. This gives you a draft with the commitment, source meeting, related handoff context, and a message template. You edit and send — the system never sends on its own.
**How**: Pattern-matches active commitments against follow-up verbs (share, send, follow up, email, etc.), cross-references people files and handoff entries, writes to `inbox/drafts/follow-ups/`.

### Weekly Review (/weekly-review)
**What**: A Friday reflection command that analyzes the past week — which threads moved, which stalled, commitment scorecard, people interactions, system health trends.
**Why**: Daily wind-down captures the trees. Weekly review shows the forest. Helps you spot patterns: are you neglecting a thread? Is a commitment going stale? Have you lost touch with someone?
**How**: Claude Code command that reads health.md history, handoff entries, threads, people, and commitments from the past 7 days, then generates a structured review.

---

## The Web UI

**What**: A local web app that lets you browse your entire brain in a browser at `http://localhost:3141`. Not deployed anywhere — it runs on your machine, reading your local files and search index.

**Why**: The terminal is great for running commands, but bad for browsing. If you want to see all your threads at a glance, read a person's full context, or search across everything — the web UI is faster and more natural than running CLI commands. It's a read-only view of the same files you already have.

### Pages

| Page | URL | What it shows |
|------|-----|---------------|
| Dashboard | `/` | Overview of everything: threads, people, open commitments, health stats |
| Timeline | `/timeline` | Handoff entries in chronological order — your daily log as a readable feed |
| Search | `/search` | Full-text search powered by the SQLite index. Finds matches across all files |
| Prep | `/prep` | Meeting prep packets with attendee context, relevant threads, commitments |
| Drafts | `/drafts` | Auto-processed transcript summaries from the background processor |
| Follow-Ups | `/follow-ups` | Draft messages for action items that involve sending something to someone |
| Thread detail | `/thread/:name` | A single thread file rendered as HTML with clickable wiki-links |
| Person detail | `/person/:name` | A single person file rendered as HTML |

### How to run it

```bash
./scripts/brain-server.sh start ~/brain    # Start server and open browser
./scripts/brain-server.sh stop             # Stop the server
./scripts/brain-server.sh status           # Check if running
```

The server reads your markdown files live on each request — no caching, no stale data. If you update a thread file and refresh the page, you see the new version immediately. Search queries go against the SQLite index (`.brain.db`), which stays up to date via the git hook.

### brain-server.sh
**What**: A start/stop/status script for the web server.
**Why**: Lets you treat the web UI like a service — start it once, forget about it, stop it when you're done. On macOS it automatically opens your browser when starting.

---

## How the Pieces Connect

```
You have meetings
       ↓
Granola records them
       ↓
Daemon snapshots transcripts to inbox (every 30 min)
       ↓
You run /wind-down in the evening
       ↓
Wind-down reads inbox → processes transcripts → proposes updates
       ↓
You review, correct, and say "commit"
       ↓
Files updated: threads, people, commitments, handoff, health
       ↓
Git commits everything
       ↓
Git hook auto-updates the search index
       ↓
Next morning, /wake-up reads the updated files
       ↓
You can also /search anytime: "what did we decide about X?"
       ↓
You get a 2-minute briefing before your first meeting
       ↓
Or browse everything in the web UI: http://localhost:3141
```

Your corrections during wind-down feed back into preferences.md, making the system smarter over time. The whole thing is a learning loop.

---

## External Integrations

Each integration is optional and independent. They extend the brain to where work actually happens.

### Slack Bot (web/integrations/slack.js)
**What**: A Slack bot that lets you interact with your brain from Slack — search, get status, view meeting prep. Also captures starred messages to your inbox automatically.
**Why**: You're already in Slack all day. Being able to `/brain search AISP` without switching to a terminal saves context switches. Starred messages become a natural "save this for later" gesture that actually works.
**How**: Uses @slack/bolt with Socket Mode (no public URL needed). Set `SLACK_BOT_TOKEN` and `SLACK_SIGNING_SECRET` env vars.

### Email (web/integrations/email.js)
**What**: An IMAP watcher that monitors a mailbox for forwarded emails and saves them to your brain's inbox as markdown.
**Why**: When someone sends you something worth remembering, forward it to your brain address. It gets processed in the next wind-down along with your meeting transcripts.
**How**: Watches a designated mailbox (like a "Brain" Gmail label). Converts emails to markdown in `inbox/email/`. Set `BRAIN_EMAIL_HOST`, `BRAIN_EMAIL_USER`, `BRAIN_EMAIL_PASS`.

### Linear (web/integrations/linear.js)
**What**: Bidirectional sync between your commitments and Linear tickets.
**Why**: Some commitments become tickets. Instead of tracking them in two places, tag a commitment with `@linear:PROJ-123` and they stay in sync. When the ticket closes in Linear, the commitment auto-completes in your brain.
**How**: Polls Linear API and handles webhooks. Set `LINEAR_API_KEY`. Trigger sync via `POST /api/linear/sync` or set up a Linear webhook.

### Browser Extension (extension/)
**What**: A Chrome extension with an "Add to Brain" button. Right-click any page (or selected text) to capture it.
**Why**: You're reading an article, a Slack thread in the browser, a Confluence page — anything worth remembering. One click captures it to your inbox with a note about why it matters.
**How**: Sends to `localhost:3141/api/inbox`. Install via Chrome → Extensions → Developer Mode → Load Unpacked → select the `extension/` folder.
