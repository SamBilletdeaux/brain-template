# Wind-Down Retrospective

Running observations about how the wind-down process performs in practice. Updated after runs to track what's working, what's not, and what to change. Observations should be confirmed across multiple sessions before becoming prompt changes.

---

## Active Observations

### Context window management (confirmed, fix shipped)
**First observed:** 2026-02-23 (runs 1-2)
**Status:** Fix shipped — process-and-flush pattern added to Phase 1

Both sessions hit context limits. Day 2 was interrupted mid-phase and had to resume from a compressed summary. Root cause: holding multiple transcripts in context simultaneously while also reading existing thread/people files.

**Fix applied:** Rewrote Phase 1 to enforce a strict process-and-flush pattern — read one transcript, write summary to disk, move on. Transcripts over ~30KB get delegated to Task agents. Phase 2+ reads only from saved summary files. Sorting by transcript size (smallest first) front-loads easy wins.

### Protocol overhead vs. value (monitoring)
**First observed:** 2026-02-24 (run 2)
**Status:** Monitoring — revisit after 5+ runs

Checkpoint files, lock acquisition, entropy checks, feedback quality monitoring, gap detection — most produced zero actionable output in the first two runs. These are safety nets that may prove their value on an off day (missed wind-down, re-run, concurrent sessions). But they consume context tokens in every run.

**Questions to answer:**
- After 5+ runs, has ANY preflight check caught a real issue?
- Has checkpoint recovery ever been used successfully?
- Has the lock prevented a real conflict?
- If not, consider making these opt-in or moving them to /doctor instead.

### Review verbosity (monitoring)
**First observed:** 2026-02-24 (run 2)
**Status:** Monitoring — revisit after 5+ runs

The Phase 4 guided review has 6 sections. User approved quickly both days with minimal corrections (1 speech-to-text fix, 0 entity decision overrides). The structure may be more than needed — but it's only been 2 runs during onboarding (unusually high approval rate when everything is new). Worth watching:
- Does the user start skipping sections?
- Do corrections increase as the domain stabilizes?
- Would a single-pass review (inline confidence markers, no section headers) be faster without losing signal?

### Raw transcript archiving (unresolved)
**First observed:** 2026-02-24 (run 2)
**Status:** Needs decision

Phase 0e specifies archiving raw transcripts to `archive/meetings/`, but in practice only summaries are being saved. Raw transcripts are large (30-130KB each) and would bloat the git repo significantly.

**Options:**
1. Archive raw transcripts (accept git bloat, or gitignore and store locally only)
2. Drop the requirement (summaries are sufficient, Granola retains originals)
3. Archive to a separate location outside git
4. Only archive when MCP is unavailable (cache-sourced transcripts are ephemeral)

### Script integration gaps (monitoring)
**First observed:** 2026-02-23 (run 1)
**Status:** Monitoring

`update-health.sh` didn't accept the expected arguments on first use — had to manually edit health.md. The agent ends up manually editing files that scripts are supposed to handle. Worth auditing which scripts are actually being called vs. bypassed.

---

## Resolved Observations

(None yet — observations move here when addressed or proven irrelevant.)

---

## Process

After each wind-down:
1. Note anything that felt wrong, slow, or wasteful
2. Check if it matches an existing observation (update it) or is new (add it)
3. After 5+ occurrences of a pattern, propose a prompt change
4. Ship the fix to the template, note it in the observation's status
