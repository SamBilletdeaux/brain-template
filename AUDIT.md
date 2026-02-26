# System Audit

An honest review of where the system stands, what's going to break, what's missing, and what needs attention. Updated after the hardening sprint.

---

## Executive Summary

The system has great bones. The core loop (wind-down → handoff → wake-up) is well-designed and the prompt engineering in the slash commands is genuinely strong. The infrastructure (validation, inbox, search index, auto-trim, session locking) is solid and tested.

The web UI works but is read-only with no interaction. The integrations (Slack, email) are structurally complete but untested against real services. The biggest gap isn't code — it's that the AI processing layer (the part that actually makes decisions about your meetings) has no automated quality checks.

**Bottom line**: Core system is production-ready. Web UI is a solid v0.1. Integrations need real-world testing.

---

## What's Actually Great

### The wind-down prompt is excellent
The 489-line wind-down command is the best part of the system. The decision frameworks (when to create threads vs. update vs. ignore), the confidence tagging system, the reinforcement loop — this is thoughtful prompt engineering. The meeting type classification and cross-meeting synthesis instructions are the kind of thing that takes multiple iterations to get right.

### The inbox pattern is resilient
The daemon + inbox + processed-marker pattern genuinely solves the "forgot to run wind-down" problem. Tested with 339 real meetings. Idempotent. This works.

### The learning loop is well-designed
preferences.md as a growing ruleset that gets read on every run is a good architecture. The wind-down prompt's Phase 5 (incorporate feedback → extract rule → save to preferences) creates a real feedback loop. Over months, this should make the system meaningfully better.

### The documentation is clear
HOW-IT-WORKS.md explains things at the right level for a non-engineer. CLAUDE.md is well-organized. The system is understandable.

---

## What's Going to Break

### 1. ~~handoff.md will become unreadable in 3 months~~ RESOLVED

**Resolution**: `scripts/auto-trim.sh` now runs automatically during every wind-down. Keeps handoff.md to 14 entries (archives older to `archive/handoffs/YYYY-QN.md`), trims health.md to 30 rows, archives completed commitments >30 days, and cleans up old inbox files. No manual intervention needed.

### 2. The search index doesn't know about inbox content

**The problem**: indexer.py only indexes markdown files in `threads/`, `people/`, `archive/meetings/`, and root files. It completely ignores:
- `inbox/prep/` — meeting prep packets
- `inbox/notes/` — captured notes
- `inbox/email/` — forwarded emails
- `inbox/slack/` — starred messages

So when you search "what prep did I generate for the Simone meeting?", the search index returns nothing. The inbox is a black hole for search.

**Fix needed**: Either index inbox content (with a separate type so it's distinguishable), or accept that inbox is ephemeral and only indexed content matters.

### 3. The web server has no authentication

**The problem**: The web UI runs on localhost:3141 with zero authentication. Anyone on your local network who can reach that port can read your brain — every thread, every person file, every commitment. The `/api/inbox` endpoint accepts POST requests from anyone, meaning any local process can inject content into your brain.

**This is especially concerning because**: If you're on a shared network (coffee shop, office), someone could potentially read your brain or inject content.

**Fix needed**: At minimum, add a bearer token check to the API endpoint. For the web UI, consider binding to 127.0.0.1 only (not 0.0.0.0) which Express does by default — verify this. A proper auth layer would be a shared secret in a config file.

### 4. The integrations are untested shells

**The problem**: Slack and email integrations are structurally complete but have never been tested against real services. They were written in one pass without iteration. Real-world issues will include:
- Slack's event subscription requires a publicly accessible URL (Socket Mode is the workaround, but needs the app-level token which is separate from the bot token)
- The IMAP watcher doesn't handle OAuth2 (Gmail requires it — app passwords are being deprecated)
- Error handling is minimal — one API failure could crash the server

**Fix needed**: Pick ONE integration, actually set it up end-to-end, and fix everything that breaks. That experience will inform what the other needs. I'd start with Slack since it has the most day-to-day utility.

---

## What's Missing Entirely

### 1. ~~Conflict detection between sessions~~ RESOLVED

**Resolution**: `scripts/brain-lock.sh` provides session lockfiles with PID tracking and stale lock detection. Wind-down acquires a lock before writing and releases it on completion.

### 2. No way to undo a bad wind-down

**The problem**: If wind-down makes a bad decision and you approve it (because you were tired, or it was in a batch of 🟢 items), the only recovery is `git revert` or manually editing files. There's no "undo last wind-down" command.

**Fix needed**: A `/rollback` command that shows the diff from the last wind-down commit and offers to revert specific files or the entire commit. Git makes this technically easy.

### 3. No data export or portability

**The problem**: The system says "portable by design (just markdown + git)" but there's no actual export function. If you wanted to switch to a different system, get a summary of everything, or share a subset of your brain with a colleague, you'd have to do it manually.

**Fix needed**: A `/export` command that can generate a standalone summary document, export specific threads with their full context, or create a shareable read-only view.

### 4. No mobile access

**The problem**: The web UI only runs on localhost. When you're on your phone between meetings and want to check your prep or search for something, you can't. This is a significant gap for a tool that's supposed to help you walk into meetings prepared.

**Fix needed**: Either tunnel the local server (ngrok/Cloudflare Tunnel) or deploy a read-only version somewhere. The Slack integration partially addresses this if you set it up, but the web UI is much richer.

### 5. No calendar integration independent of Granola

**The problem**: The system is deeply coupled to Granola for calendar data. generate-prep.py reads from Granola's cache. The wake-up command reads from Granola's cache. If you stop using Granola, or switch to a different meeting recorder, the calendar features break entirely.

**Phase 5.2 (Google Calendar OAuth) was intentionally skipped.** This was the right call for velocity, but it means the system has a single point of failure for calendar awareness. If Granola changes their cache format, or you switch to a Mac that doesn't have Granola installed, or you switch to a Linux machine — no calendar, no prep, degraded wake-up.

**Fix needed**: Abstract calendar data behind a simple interface. `scripts/get-calendar.sh` that outputs a consistent JSON format regardless of source. Implement the Granola adapter first (already have it), then add Google Calendar as a second adapter.

### 6. No observability for the snapshot daemon

**The problem**: The snapshot daemon runs silently. If it fails, you won't know. The daemon logs to `/tmp/brain-server.log` but nobody checks that.

**Fix needed**: A `/status` command or dashboard widget that shows: is the daemon running? When did it last snapshot? How many transcripts are queued?

### 7. Preferences.md has no structure validation

**The problem**: preferences.md is a free-form markdown file. Rules are written as bullet points under section headings. But there's no validation that rules are:
- Non-contradictory (rule A says "always track X", rule B says "never track X")
- Non-redundant (same rule phrased two different ways)
- Still relevant (rules from a job you left 6 months ago)

At 25+ rules, the wind-down prompt reads all of them. At 100+ rules, it could be contradictory or context-window-consuming.

**Fix needed**: Either structured rules (YAML/JSON with categories and conflict detection), or a periodic `/prune-preferences` command that identifies contradictions and staleness. The existing threshold (>25 rules → consolidation suggestion) is a start but relies on you actually doing the consolidation.

---

## Guardrails Assessment

### What exists and works
- **Confidence tagging** (🟢/🟡/🔴) — well-designed, forces transparency
- **Sensitivity rules** in preferences.md — good starting set
- **"When in doubt, don't track it"** — the right default
- **Human review before commit** — wind-down never writes without approval
- **Idempotent operations** — re-running is safe
- **Git versioning** — everything is recoverable

### What's missing

**No automated quality checks on AI output.** The system trusts Claude's wind-down output completely and relies entirely on human review. But human review degrades over time — you'll start rubber-stamping 🟢 items after a few weeks. The rubber-stamp detection threshold (3+ sessions with zero corrections) is a nudge, not a guardrail.

Ideas:
- Cross-validate extracted commitments against the transcript (does the text actually support this commitment?)
- Check for duplicate/near-duplicate thread updates (is this just restating what's already in the thread?)
- Verify that people mentioned in updates actually appear in the transcript
- Flag when a single wind-down proposes more than N changes (complexity = risk)

**No rate limiting on preference accumulation.** Every correction adds a rule. After a year of daily use, you could have 200+ rules. There's no mechanism to sunset old rules, detect conflicts, or compress similar rules into a single one. The consolidation suggestion is a good start but it's advisory, not enforced.

**No data retention policy.** Meeting transcripts in `archive/meetings/` grow forever. Inbox snapshots in `inbox/granola/` grow forever (339 meetings already). The `.brain.db` SQLite file will grow with every indexed document. After a year of heavy use, you could have 5GB+ of data with no automated cleanup.

**No input validation on the inbox API.** The `/api/inbox` endpoint accepts any JSON body. There's no size limit, no content sanitization, no rate limiting. Someone could POST a 100MB payload and crash the server, or inject markdown that breaks file parsing.

---

## Training & Onboarding Gaps

### The cold start problem
The system requires significant upfront investment before it's useful:
1. Run `/setup` — configure identity and data sources
2. Install the daemon — `./scripts/install-daemon.sh`
3. Run your first wind-down — this takes 15-20 minutes and requires active participation
4. Install the git hook — `./scripts/install-hooks.sh`
5. Optionally: start the web server, set up integrations

That's 5+ manual setup steps with no guided walkthrough. The `/setup` command handles step 1 but doesn't mention steps 2-5. A new user could easily miss the daemon installation and lose transcripts.

**Fix needed**: `/setup` should walk through ALL setup steps, not just config. Or a `/setup --full` mode that does everything.

### The "why should I bother" problem
The system only becomes valuable after 1-2 weeks of consistent use. Before that, you have 2-3 handoff entries, a few threads, and sparse people files. The wake-up briefing will be thin. The search index will have little to search.

There's no way to backfill — if you've been at a job for 6 months, you can't import your existing context. You start from zero and build up.

**Fix needed**: A `/backfill` command that processes historical transcripts from the inbox. The daemon already captures them, but wind-down only processes the most recent day by default. A dedicated backfill flow could process weeks of history in one batch.

### No documentation on what good preferences look like
The preferences.md template has placeholder sections but no real examples of good rules. A new user won't know what specificity level to aim for. "Don't track scheduling items" is good. "Be more careful" is bad. But nothing teaches this distinction.

**Fix needed**: Add 5-10 example rules in the template as commented-out examples. Show the spectrum from too-vague to too-specific to just-right.

---

## Priority Ranking

If I had to fix things in order of impact:

1. ~~**Auto-archive for handoff.md**~~ DONE — auto-trim.sh runs in every wind-down
2. ~~**Test suite for data-integrity scripts**~~ DONE — 7 test files covering core scripts
3. ~~**Lock file for concurrent sessions**~~ DONE — brain-lock.sh with PID tracking
4. **Make /setup comprehensive** — prevents broken installations
5. **Abstract calendar source** — removes Granola single point of failure
6. **Daemon observability** — prevents silent failures
7. **Web UI auth** — prevents data exposure
8. **Input validation on inbox API** — prevents crashes and injection
9. ~~**Preferences conflict detection**~~ DONE — check-preferences.sh detects contradictions
10. **One real integration end-to-end** — validates the integration architecture

---

## The Honest Bottom Line

This system is at the "impressive prototype" stage, not the "reliable daily tool" stage. The prompts are production-quality. The infrastructure is solid. But the gap between "works in a demo" and "works on day 147 when you're tired and distracted" is where most tools die.

The biggest risk isn't a specific bug — it's the slow accumulation of entropy. Files getting too long, preferences contradicting each other, the search index drifting out of sync, background processes silently failing. The system has no immune system against entropy. Adding one is the most important thing you can do next.

The second biggest risk is abandonment. The system requires daily engagement (wind-down) to stay useful. Miss a week and transcripts are gone, context is stale, and the activation energy to catch up is high. The daemon captures transcripts as a safety net, but the actual AI processing step (wind-down) is still manual and requires a Claude Code session.

Build the immune system, then stress-test it with real daily use. That's where the real learning happens.
