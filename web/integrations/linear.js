/**
 * Linear integration for Brain
 *
 * Provides:
 * - Bidirectional sync between commitments.md and Linear issues
 * - Commitments tagged @linear:ISSUE-ID sync status both ways
 * - Wind-down can optionally create Linear tickets for new commitments
 * - Webhook endpoint for Linear → Brain status updates
 *
 * Environment variables:
 *   LINEAR_API_KEY — Personal API key from linear.app/settings/api
 *
 * Setup:
 *   1. Get API key from Linear settings → API
 *   2. Set LINEAR_API_KEY env var
 *   3. Optionally set up a webhook in Linear pointing to your server
 *
 * Commitment format:
 *   - [ ] Do something — @owner — @linear:PROJ-123 — added 2026-02-18
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const LINEAR_API = 'https://api.linear.app/graphql';

function getApiKey() {
  return process.env.LINEAR_API_KEY;
}

/**
 * Make a GraphQL request to Linear API
 */
async function linearQuery(query, variables = {}) {
  const apiKey = getApiKey();
  if (!apiKey) throw new Error('LINEAR_API_KEY not set');

  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ query, variables });

    const url = new URL(LINEAR_API);
    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': apiKey,
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.errors) {
            reject(new Error(json.errors[0].message));
          } else {
            resolve(json.data);
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

/**
 * Get issue status from Linear
 */
async function getIssueStatus(issueId) {
  const data = await linearQuery(`
    query($id: String!) {
      issue(id: $id) {
        id
        identifier
        title
        state {
          name
          type
        }
        assignee {
          name
        }
      }
    }
  `, { id: issueId });

  return data.issue;
}

/**
 * Find issues by identifier (e.g., "PROJ-123")
 */
async function findIssue(identifier) {
  const data = await linearQuery(`
    query($filter: IssueFilter) {
      issues(filter: $filter, first: 1) {
        nodes {
          id
          identifier
          title
          state {
            name
            type
          }
          assignee {
            name
          }
        }
      }
    }
  `, {
    filter: {
      number: { eq: parseInt(identifier.split('-')[1]) },
      team: { key: { eq: identifier.split('-')[0] } }
    }
  });

  return data.issues.nodes[0] || null;
}

/**
 * Create a new Linear issue
 */
async function createIssue(teamKey, title, description) {
  // First find team ID
  const teamData = await linearQuery(`
    query($key: String!) {
      teams(filter: { key: { eq: $key } }) {
        nodes { id }
      }
    }
  `, { key: teamKey });

  const teamId = teamData.teams.nodes[0]?.id;
  if (!teamId) throw new Error(`Team "${teamKey}" not found`);

  const data = await linearQuery(`
    mutation($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue {
          id
          identifier
          title
          url
        }
      }
    }
  `, {
    input: {
      teamId,
      title,
      description,
    }
  });

  return data.issueCreate.issue;
}

/**
 * Parse @linear:PROJ-123 tags from commitments.md
 */
function parseLinearTags(commitmentsPath) {
  if (!fs.existsSync(commitmentsPath)) return [];

  const content = fs.readFileSync(commitmentsPath, 'utf-8');
  const tags = [];
  const lines = content.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(/@linear:([A-Z]+-\d+)/);
    if (match) {
      const isCompleted = lines[i].startsWith('- [x]');
      tags.push({
        identifier: match[1],
        line: i,
        text: lines[i],
        isCompleted,
      });
    }
  }

  return tags;
}

/**
 * Sync Linear issue statuses with commitments.md
 * Returns a list of changes made
 */
async function syncFromLinear(brainRoot) {
  if (!getApiKey()) return [];

  const commitmentsPath = path.join(brainRoot, 'commitments.md');
  const tags = parseLinearTags(commitmentsPath);
  const changes = [];

  for (const tag of tags) {
    if (tag.isCompleted) continue;  // already done in brain

    try {
      const issue = await findIssue(tag.identifier);
      if (!issue) continue;

      // If Linear says done, mark commitment as complete
      if (issue.state.type === 'completed' || issue.state.type === 'canceled') {
        const content = fs.readFileSync(commitmentsPath, 'utf-8');
        const lines = content.split('\n');
        lines[tag.line] = lines[tag.line].replace('- [ ]', '- [x]');
        lines[tag.line] += ` (completed via Linear ${new Date().toISOString().split('T')[0]})`;
        fs.writeFileSync(commitmentsPath, lines.join('\n'));

        changes.push({
          type: 'completed',
          identifier: tag.identifier,
          title: issue.title,
          state: issue.state.name,
        });
      }
    } catch (e) {
      console.error(`Linear sync error for ${tag.identifier}:`, e.message);
    }
  }

  return changes;
}

/**
 * Express routes for Linear integration
 */
function addLinearRoutes(app, brainRoot) {
  if (!getApiKey()) {
    console.log('Linear: LINEAR_API_KEY not set, skipping');
    return;
  }

  // Manual sync trigger
  app.post('/api/linear/sync', async (req, res) => {
    try {
      const changes = await syncFromLinear(brainRoot);
      res.json({ ok: true, changes });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  // Webhook endpoint for Linear events
  app.post('/api/linear/webhook', async (req, res) => {
    const { type, data } = req.body;

    if (type === 'Issue' && data) {
      const commitmentsPath = path.join(brainRoot, 'commitments.md');
      const identifier = data.identifier || `${data.team?.key}-${data.number}`;

      // Check if this issue is tracked in commitments
      const tags = parseLinearTags(commitmentsPath);
      const tracked = tags.find(t => t.identifier === identifier);

      if (tracked && !tracked.isCompleted && data.state?.type === 'completed') {
        const content = fs.readFileSync(commitmentsPath, 'utf-8');
        const lines = content.split('\n');
        lines[tracked.line] = lines[tracked.line].replace('- [ ]', '- [x]');
        lines[tracked.line] += ` (completed via Linear ${new Date().toISOString().split('T')[0]})`;
        fs.writeFileSync(commitmentsPath, lines.join('\n'));
      }
    }

    res.json({ ok: true });
  });

  // Create issue from commitment
  app.post('/api/linear/create', async (req, res) => {
    const { team, title, description } = req.body;
    if (!team || !title) {
      return res.status(400).json({ error: 'team and title required' });
    }

    try {
      const issue = await createIssue(team, title, description || '');
      res.json({ ok: true, issue });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });

  console.log('Linear: connected');
}

module.exports = { addLinearRoutes, syncFromLinear, createIssue, findIssue };
