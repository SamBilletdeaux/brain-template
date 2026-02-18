# Brain Configuration

Read by every command before execution. Edit directly or re-run `/setup` to regenerate.

---

## Identity
- **Name**: (run /setup to configure)
- **Role**: (run /setup to configure)
- **Context**: (run /setup to configure)

## Data Sources
<!-- Each source has a type, location, and any special parsing notes.
     Commands iterate through this list to find today's inputs. -->

(No sources configured. Run /setup to add your meeting recording tool.)

<!-- Examples of configured sources:

### Primary: Granola
- **Type**: granola
- **Cache path**: ~/Library/Application Support/Granola/cache-v3.json
- **Parse method**: `data.cache` (JSON string) → `state.documents` (dict), `state.transcripts` (dict keyed by document ID)
- **Calendar data**: Available via `google_calendar_event` on each document
- **Transcript retention**: ~1 day in local cache (process same-day)
- **Known quirks**:
  - `notes_markdown` field is always empty (notes are cloud-only)
  - No speaker identification in transcripts

### Otter.ai
- **Type**: otter
- **Export path**: ~/Documents/Otter/
- **Format**: .txt exports with speaker labels
- **Notes**: Auto-exports if configured in Otter settings

### Zoom Transcripts
- **Type**: file-drop
- **Location**: ~/Downloads/ (manual upload during asset collection)
- **Format**: .vtt or .txt
- **Notes**: Zoom transcripts DO have speaker labels

### Fireflies.ai
- **Type**: fireflies
- **Export path**: ~/Documents/Fireflies/
- **Format**: .json or .txt with speaker labels, action items, and summaries
- **Notes**: Has its own AI summaries — can be used as a cross-reference

### Manual Paste
- **Type**: file-drop
- **Location**: manual paste during asset collection
- **Format**: raw text
- **Notes**: No structured format, treat as supplementary context

-->

## Paths
- **Brain root**: ~/brain/
- **Archive**: ~/brain/archive/
- **Commands**: ~/brain/commands/

## Job Transition History
<!-- When switching jobs, /setup adds an entry here and archives the old context. -->

| Date | Context | Action |
|------|---------|--------|
| | | (no transitions yet) |
