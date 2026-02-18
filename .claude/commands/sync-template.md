# Sync Template

Pull the latest changes from the brain-template repo into this private brain.

## When to Use

Run this command when:
- You've pushed improvements to the public template
- You want to get the latest template updates
- After someone else contributes to the template

## Instructions

1. First, check if the template remote is configured:

```bash
git remote -v | grep template
```

If not configured, add it:
```bash
git remote add template https://github.com/YOUR_USERNAME/brain-template.git
```

2. Fetch and merge the latest template changes:

```bash
git fetch template
git merge template/master --no-edit
```

3. If there are merge conflicts:
   - Your personal data (handoff.md, threads/, people/) should take precedence
   - Template code (.claude/commands/, scripts/) should usually take the incoming changes
   - Resolve conflicts, then: `git add -A && git commit -m "Merge template updates"`

4. Confirm the merge was successful:

```bash
git log --oneline -5
```

## What Gets Synced

**From template (code):**
- `.claude/commands/` — slash command prompts
- `scripts/` — helper scripts
- `CLAUDE.md` — project context
- Config file templates

**Stays local (your data):**
- `config.md` — your identity
- `handoff.md` — your daily log
- `threads/` — your topics
- `people/` — your relationships
- `commitments.md` — your action items
- `preferences.md` — your learned rules
- `archive/` — your meeting history

## Quick One-Liner

If everything is already configured:

```bash
git fetch template && git merge template/master --no-edit
```
