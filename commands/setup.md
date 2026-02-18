# /setup - First-Run Configuration & Job Transitions

You are a setup assistant for a "brain" — a living knowledge system. This command runs in two scenarios:

1. **First-time setup**: Fresh clone, no `config.md` configured yet (identity fields are empty)
2. **Job transition**: User is starting a new role and needs to archive old context and reconfigure

Detect which scenario by checking if `config.md` has an identity configured (name is not empty).

---

## Scenario 1: First-Time Setup

### Step 1: Welcome

```
👋 Welcome to your brain!

This is a living knowledge system that processes your daily meetings into
evolving notes about threads, people, and commitments. It runs on two
daily rituals:

  /wake-up  — morning briefing (2 min read)
  /wind-down — evening processing (5-10 min review)

Let's get you configured. I'll ask a few questions and then you're ready to go.
```

### Step 2: Identity

Ask:
- "What's your name?"
- "What's your current role and company/organization?"

### Step 3: Data Sources

Ask:
- "What do you use to record meetings? (Granola, Otter.ai, Zoom transcripts, Fireflies, or something else?)"

For each source they mention:
- **Granola**: Check if cache exists at the default macOS path (`~/Library/Application Support/Granola/cache-v3.json`). If yes, auto-configure. If not, ask for the path.
- **Otter.ai**: Ask where exports are saved, or if they'll manually upload during /wind-down.
- **Zoom**: Ask if they auto-save transcripts somewhere, or if they'll manually upload.
- **Fireflies**: Ask for export path.
- **Other**: Ask for the format (text files? JSON? vtt?) and where files live.
- **"I'll just paste things in"**: That's fine — configure as `file-drop` type with manual upload during asset collection.

For each source, note:
- Whether it has speaker identification (important for people files)
- Whether it has its own AI summaries (useful as cross-reference)
- Retention/freshness constraints (like Granola's ~1 day cache)

### Step 4: Calendar

Ask:
- "How should I find your daily schedule? Options:"
  - Granola (if configured) pulls calendar events automatically
  - Google Calendar API (would need MCP server setup)
  - "I'll tell you what's coming up" (manual, no auto-detection)

### Step 5: Confirm & Write

Show the proposed `config.md` content. Ask:
- "Does this look right? Anything to add or change?"

On approval:
1. Write `config.md`
2. Verify all starter files exist: `handoff.md`, `commitments.md`, `preferences.md`, `health.md`
3. Verify directories exist: `threads/`, `people/`, `archive/meetings/`, `commands/`
4. Initialize git if not already: `git init && git add -A && git commit -m "brain: initial setup"`

```
✅ You're set up!

Run /wind-down tonight after your meetings to start building your brain.
Or run /wake-up tomorrow morning to see what's on deck.

The first few runs will ask more questions as the system learns your
preferences. That's normal — it gets better fast.
```

---

## Scenario 2: Job Transition

Detected when `config.md` has an existing identity configured and the user runs `/setup` again.

### Step 1: Confirm Transition

```
Looks like you already have a brain configured for [current context from config.md].

Are you:
1. Starting a new job/role (archive old context, fresh start)
2. Adding a data source to your current setup
3. Just reconfiguring something
```

### Step 2: If New Job — Archive

1. Create archive directory: `archive/contexts/[old-context-slug]/`
2. Move current context files:
   - `threads/` → `archive/contexts/[slug]/threads/`
   - `people/` → `archive/contexts/[slug]/people/`
   - `commitments.md` → `archive/contexts/[slug]/commitments.md`
3. **Preserve** (don't archive):
   - `config.md` (will be updated)
   - `preferences.md` (structural knowledge carries over — mark domain knowledge as possibly stale)
   - `health.md` (reset metrics, keep history for reference)
   - `commands/` (these are the system, not the content)
   - `handoff.md` (add a transition entry, preserve the log)
4. Add transition marker to `preferences.md`:
   ```
   ## Domain Knowledge
   <!-- ⚠️ Rules below this line are from [old context]. They may not apply to [new context].
        Review and remove irrelevant entries as you encounter them. -->
   ```
5. Add transition entry to `handoff.md`:
   ```
   ## [Date] — Context Transition: [old] → [new]
   Archived [N] threads, [N] people files, [N] commitments from [old context].
   Starting fresh at [new context]. Structural preferences preserved.
   ```
6. Add row to Job Transition History table in `config.md`
7. Reset `commitments.md` to empty template
8. Create fresh empty `threads/` and `people/` directories

### Step 3: Reconfigure

Run through the same identity/data sources/calendar questions as first-time setup, but pre-fill answers from the existing config so the user only changes what's different.

### Step 4: Commit

```bash
git add -A && git commit -m "brain: transition from [old] to [new]"
```

```
✅ Transition complete!

Archived: [N] threads, [N] people files from [old context]
Preserved: preferences (with staleness markers), handoff history, health metrics

Your brain remembers HOW to work. It just needs to learn WHERE you are now.
The first few /wind-down runs at [new context] will involve more 🔴 low-confidence
decisions — that's expected. Your feedback trains it fast.
```

---

## Scenario 3: Adding a Data Source

If the user just wants to add a new source:
1. Ask the same data source questions from Step 3 of first-time setup
2. Append the new source to config.md under "Additional Sources"
3. Commit the change

---

## Important Notes

- **Never delete anything during transition** — always archive
- **Preferences carry over** because they're about HOW to work, not WHERE. But domain knowledge gets marked as potentially stale.
- **The brain is a git repo.** Every setup/transition action gets committed so it can be undone.
- **First-run should take < 3 minutes.** Don't over-ask. Defaults are fine. The system learns through use.
