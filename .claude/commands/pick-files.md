# Pick Files

Open a native macOS file picker to select files for processing.

## Usage

Run this command when you need to select files (e.g., meeting transcripts, documents to process).

## Instructions

1. Run the file picker script:

```bash
./scripts/pick-files.sh "Select meeting files to process:"
```

2. A native Finder window will open
3. Select one or more files (hold Cmd to select multiple)
4. Click "Choose"
5. The selected file paths will be returned, one per line

## Integration with /wind-down

During the wind-down ritual, when prompted for additional files:

1. Run `/pick-files`
2. Select the meeting transcripts or notes
3. The paths will be available for processing

## Notes
- Only works on macOS (uses native Finder dialog)
- Supports multiple file selection
- Returns absolute POSIX paths
