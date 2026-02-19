/**
 * Slack integration for Brain
 *
 * Provides:
 * - /brain slash command (search, prep, status)
 * - Starred message capture to inbox
 * - Morning briefing delivery as DM
 *
 * Environment variables:
 *   SLACK_BOT_TOKEN      — Bot User OAuth Token (xoxb-...)
 *   SLACK_SIGNING_SECRET  — Signing secret for request verification
 *   SLACK_APP_TOKEN       — App-level token for Socket Mode (xapp-...)
 *
 * Setup:
 *   1. Create a Slack app at api.slack.com/apps
 *   2. Enable Socket Mode
 *   3. Add slash command: /brain
 *   4. Subscribe to events: star_added
 *   5. Add bot scopes: commands, chat:write, stars:read, im:write
 *   6. Install to workspace
 *   7. Set env vars and restart brain server
 */

const fs = require('fs');
const path = require('path');

let bolt;
try {
  bolt = require('@slack/bolt');
} catch (e) {
  // Slack SDK not installed — that's fine, integration is optional
}

function createSlackApp(brainRoot, db, renderMarkdown) {
  if (!bolt) {
    console.log('Slack: @slack/bolt not installed. Run: npm install @slack/bolt');
    return null;
  }

  const token = process.env.SLACK_BOT_TOKEN;
  const signingSecret = process.env.SLACK_SIGNING_SECRET;
  const appToken = process.env.SLACK_APP_TOKEN;

  if (!token || !signingSecret) {
    console.log('Slack: SLACK_BOT_TOKEN and SLACK_SIGNING_SECRET not set, skipping');
    return null;
  }

  const appOpts = {
    token,
    signingSecret,
  };

  // Use Socket Mode if app token available (no public URL needed)
  if (appToken) {
    appOpts.socketMode = true;
    appOpts.appToken = appToken;
  }

  const app = new bolt.App(appOpts);

  // --- /brain slash command ---
  app.command('/brain', async ({ command, ack, respond }) => {
    await ack();

    const args = command.text.trim().split(/\s+/);
    const subcommand = args[0] || 'help';
    const query = args.slice(1).join(' ');

    switch (subcommand) {
      case 'search': {
        if (!query) {
          await respond('Usage: `/brain search <query>`');
          return;
        }
        if (!db) {
          await respond('Search index not available. Run indexer.py first.');
          return;
        }
        try {
          const results = db.prepare(`
            SELECT d.path, d.type,
                   snippet(search_index, 0, '*', '*', '...', 24) as snippet
            FROM search_index s
            JOIN documents d ON d.id = s.rowid
            WHERE search_index MATCH ?
            ORDER BY rank
            LIMIT 5
          `).all(query);

          if (results.length === 0) {
            await respond(`No results for "${query}"`);
            return;
          }

          const blocks = [{
            type: 'header',
            text: { type: 'plain_text', text: `Search: ${query}` }
          }];

          for (const r of results) {
            const name = path.basename(r.path, '.md');
            blocks.push({
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: `*${name}* (${r.type})\n${r.snippet}`
              }
            });
          }

          await respond({ blocks });
        } catch (e) {
          await respond(`Search error: ${e.message}`);
        }
        break;
      }

      case 'status': {
        const healthPath = path.join(brainRoot, 'health.md');
        const commitmentsPath = path.join(brainRoot, 'commitments.md');

        let statusText = '';

        if (fs.existsSync(healthPath)) {
          const health = fs.readFileSync(healthPath, 'utf-8');
          const date = health.match(/\*\*Date\*\*:\s*(.+)/);
          const meetings = health.match(/\*\*Meetings processed\*\*:\s*(.+)/);
          const consecutive = health.match(/\*\*Consecutive days run\*\*:\s*(.+)/);

          statusText += '*Last wind-down*\n';
          if (date) statusText += `• Date: ${date[1]}\n`;
          if (meetings) statusText += `• Meetings: ${meetings[1]}\n`;
          if (consecutive) statusText += `• Streak: ${consecutive[1]} days\n`;
        }

        if (fs.existsSync(commitmentsPath)) {
          const commitments = fs.readFileSync(commitmentsPath, 'utf-8');
          const active = (commitments.match(/^- \[ \]/gm) || []).length;
          statusText += `\n*Commitments*: ${active} active\n`;
        }

        // Thread count
        const threadsDir = path.join(brainRoot, 'threads');
        if (fs.existsSync(threadsDir)) {
          const threads = fs.readdirSync(threadsDir).filter(f => f.endsWith('.md'));
          statusText += `*Threads*: ${threads.length}\n`;
        }

        await respond(statusText || 'No brain data found');
        break;
      }

      case 'prep': {
        const prepDir = path.join(brainRoot, 'inbox', 'prep');
        if (!fs.existsSync(prepDir)) {
          await respond('No prep packets. Run: `python3 scripts/generate-prep.py ~/brain`');
          return;
        }

        const today = new Date().toISOString().split('T')[0];
        const files = fs.readdirSync(prepDir)
          .filter(f => f.endsWith('.md') && f.startsWith(today));

        if (files.length === 0) {
          await respond(`No prep packets for today (${today})`);
          return;
        }

        const blocks = [{
          type: 'header',
          text: { type: 'plain_text', text: `Meeting Prep — ${today}` }
        }];

        for (const f of files) {
          const content = fs.readFileSync(path.join(prepDir, f), 'utf-8');
          // Truncate for Slack's 3000 char limit per block
          const truncated = content.length > 2800
            ? content.slice(0, 2800) + '\n...(truncated)'
            : content;

          blocks.push({
            type: 'section',
            text: { type: 'mrkdwn', text: truncated }
          });
        }

        await respond({ blocks });
        break;
      }

      default:
        await respond(
          '*Brain Commands*\n' +
          '• `/brain search <query>` — search your brain\n' +
          '• `/brain status` — system overview\n' +
          '• `/brain prep` — today\'s meeting prep\n' +
          '• `/brain help` — this message'
        );
    }
  });

  // --- Star capture ---
  app.event('star_added', async ({ event, client }) => {
    try {
      // Get the starred message
      const item = event.item;
      if (item.type !== 'message') return;

      const result = await client.conversations.history({
        channel: item.channel,
        latest: item.message.ts,
        inclusive: true,
        limit: 1,
      });

      if (!result.messages || !result.messages[0]) return;

      const message = result.messages[0];
      const text = message.text || '';

      // Get channel name
      let channelName = item.channel;
      try {
        const channelInfo = await client.conversations.info({ channel: item.channel });
        channelName = channelInfo.channel.name || item.channel;
      } catch (e) {
        // private channel or DM, use ID
      }

      // Save to inbox
      const inboxDir = path.join(brainRoot, 'inbox', 'slack');
      fs.mkdirSync(inboxDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `${timestamp}-${channelName}.md`;

      const content = [
        '---',
        `source: slack`,
        `channel: #${channelName}`,
        `starred_at: ${new Date().toISOString()}`,
        `user: ${message.user || 'unknown'}`,
        '---',
        '',
        text,
      ].join('\n');

      fs.writeFileSync(path.join(inboxDir, filename), content);
    } catch (e) {
      console.error('Slack star capture error:', e.message);
    }
  });

  return app;
}

/**
 * Send a DM to a user (for briefings, prep delivery)
 */
async function sendDM(app, userId, text, blocks) {
  if (!app) return;

  try {
    const result = await app.client.conversations.open({ users: userId });
    const channel = result.channel.id;

    await app.client.chat.postMessage({
      channel,
      text,
      blocks,
    });
  } catch (e) {
    console.error('Slack DM error:', e.message);
  }
}

module.exports = { createSlackApp, sendDM };
