# /doctor - Brain System Health Check

You are a diagnostic agent for the user's brain system. Run a comprehensive health check and report findings.

## Setup

Read `config.md` first to get brain root path and data source configuration.

## Checks to Run

Run ALL of the following checks and report results:

### 1. Config Validation
Run `scripts/validate-config.sh` and report any errors or warnings.

### 2. Referential Integrity
Scan all files in `threads/` and `people/` for `[[wiki-links]]`.
- For each link, check if a matching file exists in `threads/` or `people/`
- Report any broken links: `[[nonexistent-thread]]` in file X

### 3. Stale Commitments
Read `commitments.md`. For each active commitment:
- Parse the `added [date]` field
- Check the stale commitment threshold in `preferences.md` (default: 5 days)
- Flag any commitment older than the threshold as ⚠️ STALE

### 4. Dormant Threads
Read each file in `threads/`. For each thread:
- Find the most recent date mentioned in the History section
- Check the thread pruning threshold in `preferences.md` (default: 30 days)
- Flag any thread dormant longer than the threshold as 💤 DORMANT

### 5. File Growth
Report sizes and line counts for:
- `handoff.md` — warn if >500 lines (suggest archival)
- `commitments.md` — warn if Completed section has >20 items
- `preferences.md` — warn if >25 rules (per threshold)
- `health.md` — warn if >100 history rows

### 6. Granola Cache Status
If Granola is configured as a data source:
- Check if cache file exists and is readable
- Report cache file size
- Report most recent meeting date in cache
- Warn if no meetings from today (may indicate Granola isn't running)

### 7. Git Status
Run `git status` in the brain root:
- Report uncommitted changes
- Report unpushed commits
- Report current branch

### 8. System Thresholds
Read thresholds from `preferences.md` and check each one:
- Thread count warning (default: >20 threads)
- People file archival suggestion (default: >15 people files)
- Preferences consolidation suggestion (default: >25 rules)

## Output Format

Present results as a scannable report:

```
🏥 Brain Health Check — YYYY-MM-DD

✅ Config: Valid (Name: X, Role: Y, Sources: N)
✅ Links: All 12 wiki-links resolve
⚠️ Commitments: 2 stale (>5 days)
   - "Send AISP analysis to Wei" (added Feb 10)
   - "Draft content agent PRD" (added Feb 8)
✅ Threads: 4 active, 0 dormant
✅ File sizes: All within limits
⚠️ Granola: No meetings from today in cache
✅ Git: Clean, up to date
✅ Thresholds: All within limits

Summary: 2 warnings, 0 errors
```

After the report, offer:
> "Want me to fix any of these? I can:
> - Run archival to trim large files
> - Help update stale commitments
> - Archive dormant threads"
