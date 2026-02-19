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
Next morning, /wake-up reads the updated files
       ↓
You get a 2-minute briefing before your first meeting
```

Your corrections during wind-down feed back into preferences.md, making the system smarter over time. The whole thing is a learning loop.
