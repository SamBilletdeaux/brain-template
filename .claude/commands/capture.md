# Capture Session Context

Review this conversation and identify **stable facts** that should be preserved in CLAUDE.md for future sessions.

## What to Look For

**Capture these (stable facts):**
- Decisions made ("we decided to use X pattern")
- Architecture/structure established ("commands live in .claude/commands/")
- Gotchas discovered ("don't run X, it breaks Y")
- Workflows defined ("template changes go to repo A, then pull into repo B")
- Important locations ("API keys are stored in Z")
- Tool configurations set up

**Don't capture these (ephemeral):**
- Explanations or tutorials given
- Troubleshooting steps that worked
- General conversation
- Things already documented elsewhere

## Process

1. Review the conversation for stable facts
2. Read the current CLAUDE.md
3. Identify what's missing or needs updating
4. Present the proposed additions to the user in a clear format:

```
## Proposed CLAUDE.md Updates

### Add:
- [new fact 1]
- [new fact 2]

### Update:
- [existing section] → [proposed change]

### No changes needed:
- [fact already captured]
```

5. After user approval, update CLAUDE.md and commit the changes

## Important
- Be selective. CLAUDE.md should stay concise and scannable.
- When in doubt, leave it out. Only truly stable facts belong here.
- If nothing needs capturing, say so! Not every session has CLAUDE.md-worthy content.
