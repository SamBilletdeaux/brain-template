# Integration Setup Guide

Step-by-step guides for connecting external services to your brain.

---

## Granola MCP (Meeting Data)

The preferred way to get meeting data. Uses Granola's API directly instead of scraping the local cache.

### Prerequisites
- Granola app installed and signed in
- `uv` installed: `brew install uv`

### Installation
```bash
# Clone the MCP server
git clone https://github.com/chrisguillory/granola-mcp.git ~/granola-mcp

# Register with Claude Code
claude mcp add --scope user --transport stdio granola -- uv run --script ~/granola-mcp/granola-mcp.py
```

### Verify
```bash
claude mcp list
# Should show: granola (stdio)
```

The server reads OAuth tokens from `~/Library/Application Support/Granola/supabase.json` (auto-populated by the Granola app).

### Available Tools
- `search_meetings` — Search meetings by date or keyword
- `download_transcript` — Get full transcript for a meeting
- `download_note` — Get Granola's AI-generated notes
- `get_meeting_lists` — List upcoming/recent meetings

### Troubleshooting
- **"supabase.json not found"**: Open the Granola app and sign in. The file is created on login.
- **Token expired**: Close and reopen Granola — it refreshes tokens on launch.
- **MCP tools not available**: Run `claude mcp list` to verify registration. Restart Claude Code after adding.

### Fallback
If MCP is unavailable, wind-down and wake-up automatically fall back to:
1. Inbox snapshots (`inbox/granola/`)
2. Live Granola cache (`~/Library/Application Support/Granola/cache-v3.json`)

---

## Slack

Chat with your brain from Slack via the `/brain` slash command. Also captures starred messages to your inbox.

### Setup

1. **Create a Slack app** at [api.slack.com/apps](https://api.slack.com/apps)
2. **Enable Socket Mode**:
   - Settings → Socket Mode → Enable
   - Generate an App-Level Token with `connections:write` scope
   - Save the `xapp-...` token
3. **Add slash command**:
   - Features → Slash Commands → Create New Command
   - Command: `/brain`
   - Request URL: (any URL — Socket Mode bypasses this)
   - Description: "Search and interact with your brain"
4. **Subscribe to events**:
   - Features → Event Subscriptions → Enable
   - Subscribe to bot event: `star_added`
5. **Add bot scopes**:
   - Features → OAuth & Permissions → Bot Token Scopes
   - Add: `commands`, `chat:write`, `stars:read`, `im:write`, `channels:history`
6. **Install to workspace**:
   - Settings → Install App → Install to Workspace
   - Copy the Bot User OAuth Token (`xoxb-...`)
7. **Set environment variables**:
   ```bash
   export SLACK_BOT_TOKEN="xoxb-..."
   export SLACK_SIGNING_SECRET="..."      # From Basic Information page
   export SLACK_APP_TOKEN="xapp-..."       # From Socket Mode page
   ```
8. **Start the brain server**:
   ```bash
   ./scripts/brain-server.sh start ~/brain
   ```

### Test
- In Slack: `/brain status` — should show your brain stats
- In Slack: `/brain search <topic>` — should return results
- Star a message — should appear in `inbox/slack/`

### Troubleshooting
- **"SLACK_APP_TOKEN required"**: Socket Mode is mandatory. Generate an app-level token in your Slack app settings.
- **Connection drops**: The bot auto-reconnects with exponential backoff (up to 5 attempts).
- **Check status**: `curl http://localhost:3141/api/integrations/status | jq .slack`

---

## Gmail (Email Capture)

Forward emails to your brain. They get saved as markdown in your inbox for the next wind-down.

### Setup

1. **Enable 2-Factor Authentication** on your Google account
2. **Create an app password**:
   - Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
   - Select "Mail" and your device
   - Copy the 16-character password
3. **Create a Gmail label** called "Brain" (optional — defaults to INBOX)
4. **Set environment variables**:
   ```bash
   export BRAIN_EMAIL_HOST="imap.gmail.com"
   export BRAIN_EMAIL_USER="you@gmail.com"
   export BRAIN_EMAIL_PASS="xxxx xxxx xxxx xxxx"  # App password
   export BRAIN_EMAIL_MAILBOX="Brain"               # Optional, defaults to "Brain"
   ```
5. **Start the brain server**:
   ```bash
   ./scripts/brain-server.sh start ~/brain
   ```

### Usage
- Forward any email to yourself
- If using a "Brain" label: apply the label to the email
- If using INBOX: any unread email in INBOX gets captured

Emails are saved as markdown to `inbox/email/` with metadata (from, subject, date).

### Test
- Forward a test email
- Check `inbox/email/` for the saved markdown file
- Check status: `curl http://localhost:3141/api/integrations/status | jq .email`

### Troubleshooting
- **"Less secure app" error**: You must use an app password, not your regular password. Google blocks plain password auth.
- **Connection drops**: The watcher auto-reconnects after 30 seconds.
- **Wrong mailbox**: Set `BRAIN_EMAIL_MAILBOX` to match your label name exactly.
