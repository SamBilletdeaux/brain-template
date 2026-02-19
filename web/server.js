#!/usr/bin/env node
// brain-web — local web UI for browsing your brain
//
// Usage:
//   node web/server.js --brain ~/brain
//   node web/server.js --brain ~/brain --port 3141

const express = require('express');
const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');
const { marked } = require('marked');

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { port: 3141, brain: null };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--brain' && args[i + 1]) {
      opts.brain = args[++i];
    } else if (args[i] === '--port' && args[i + 1]) {
      opts.port = parseInt(args[++i], 10);
    }
  }

  if (!opts.brain) {
    console.error('Usage: node server.js --brain <path-to-brain>');
    process.exit(1);
  }

  // Resolve ~ to home directory
  if (opts.brain.startsWith('~')) {
    opts.brain = path.join(process.env.HOME, opts.brain.slice(1));
  }
  opts.brain = path.resolve(opts.brain);

  if (!fs.existsSync(opts.brain)) {
    console.error(`Brain directory not found: ${opts.brain}`);
    process.exit(1);
  }

  return opts;
}

const opts = parseArgs();

// ---------------------------------------------------------------------------
// Database connection
// ---------------------------------------------------------------------------

const dbPath = path.join(opts.brain, '.brain.db');
let db = null;

if (fs.existsSync(dbPath)) {
  db = new Database(dbPath, { readonly: true });
  db.pragma('journal_mode = WAL');
} else {
  console.warn(`Warning: SQLite index not found at ${dbPath}`);
  console.warn('Search and graph features will be unavailable.');
  console.warn('Run: python3 scripts/indexer.py <brain-path> to build the index.');
}

// ---------------------------------------------------------------------------
// Markdown rendering
// ---------------------------------------------------------------------------

// Convert [[wiki-links]] to clickable links
function renderMarkdown(content) {
  // Replace [[thread-name]] with links
  const withLinks = content.replace(/\[\[([^\]]+)\]\]/g, (match, name) => {
    const slug = name.toLowerCase().replace(/\s+/g, '-');
    // Check if it's a person or thread
    const personPath = path.join(opts.brain, 'people', `${slug}.md`);
    const threadPath = path.join(opts.brain, 'threads', `${slug}.md`);
    if (fs.existsSync(personPath)) {
      return `[${name}](/person/${slug})`;
    } else if (fs.existsSync(threadPath)) {
      return `[${name}](/thread/${slug})`;
    }
    return `[${name}](#)`;
  });

  return marked(withLinks);
}

// Read a markdown file and return { raw, html, exists }
function readMarkdownFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return { raw: '', html: '', exists: false };
  }
  const raw = fs.readFileSync(filePath, 'utf-8');
  return { raw, html: renderMarkdown(raw), exists: true };
}

// ---------------------------------------------------------------------------
// Template engine (simple string replacement, no dependencies)
// ---------------------------------------------------------------------------

const layoutHtml = fs.readFileSync(
  path.join(__dirname, 'views', 'layout.html'),
  'utf-8'
);

function render(res, pageTemplate, data = {}) {
  let page = fs.readFileSync(
    path.join(__dirname, 'views', pageTemplate),
    'utf-8'
  );

  // Replace {{variable}} patterns in the page template
  for (const [key, value] of Object.entries(data)) {
    page = page.replace(new RegExp(`\\{\\{${key}\\}\\}`, 'g'), value ?? '');
  }

  // Insert page into layout
  const title = data.title || 'Brain';
  let html = layoutHtml
    .replace('{{title}}', title)
    .replace('{{content}}', page);

  res.type('html').send(html);
}

// ---------------------------------------------------------------------------
// Express app
// ---------------------------------------------------------------------------

const app = express();

app.use('/public', express.static(path.join(__dirname, 'public')));

// Make brain path and db available to routes
app.use((req, res, next) => {
  req.brain = opts.brain;
  req.db = db;
  req.renderMarkdown = renderMarkdown;
  req.readMarkdownFile = readMarkdownFile;
  next();
});

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

// Dashboard
app.get('/', (req, res) => {
  // Read key files
  const handoff = readMarkdownFile(path.join(opts.brain, 'handoff.md'));
  const commitments = readMarkdownFile(path.join(opts.brain, 'commitments.md'));
  const health = readMarkdownFile(path.join(opts.brain, 'health.md'));

  // List threads
  const threadsDir = path.join(opts.brain, 'threads');
  const threads = fs.existsSync(threadsDir)
    ? fs.readdirSync(threadsDir)
        .filter(f => f.endsWith('.md'))
        .map(f => {
          const stat = fs.statSync(path.join(threadsDir, f));
          return {
            name: f.replace('.md', ''),
            slug: f.replace('.md', ''),
            updated: stat.mtime.toISOString().split('T')[0],
          };
        })
        .sort((a, b) => b.updated.localeCompare(a.updated))
    : [];

  // List people
  const peopleDir = path.join(opts.brain, 'people');
  const people = fs.existsSync(peopleDir)
    ? fs.readdirSync(peopleDir)
        .filter(f => f.endsWith('.md'))
        .map(f => {
          const stat = fs.statSync(path.join(peopleDir, f));
          return {
            name: f.replace('.md', '').replace(/-/g, ' '),
            slug: f.replace('.md', ''),
            updated: stat.mtime.toISOString().split('T')[0],
          };
        })
        .sort((a, b) => b.updated.localeCompare(a.updated))
    : [];

  // Parse active commitments
  const activeCommitments = commitments.raw
    .split('\n')
    .filter(line => line.match(/^- \[ \]/))
    .map(line => line.replace(/^- \[ \] /, ''));

  // Parse latest health run
  const healthLines = health.raw.split('\n');
  const latestDate = healthLines.find(l => l.includes('**Date**:'));
  const latestMeetings = healthLines.find(l => l.includes('**Meetings processed**:'));
  const consecutiveDays = healthLines.find(l => l.includes('**Consecutive days run**:'));

  // Build threads HTML
  const threadsHtml = threads.map(t =>
    `<li><a href="/thread/${t.slug}">${t.name}</a> <span class="meta">updated ${t.updated}</span></li>`
  ).join('\n');

  // Build people HTML
  const peopleHtml = people.map(p =>
    `<li><a href="/person/${p.slug}">${p.name}</a> <span class="meta">updated ${p.updated}</span></li>`
  ).join('\n');

  // Build commitments HTML
  const commitmentsHtml = activeCommitments.length > 0
    ? activeCommitments.map(c => `<li>${renderMarkdown(c)}</li>`).join('\n')
    : '<li class="empty">No active commitments</li>';

  // Health summary
  const healthSummary = [latestDate, latestMeetings, consecutiveDays]
    .filter(Boolean)
    .map(l => `<li>${renderMarkdown(l.replace(/^- /, ''))}</li>`)
    .join('\n');

  render(res, 'dashboard.html', {
    title: 'Dashboard',
    threads: threadsHtml,
    people: peopleHtml,
    commitments: commitmentsHtml,
    healthSummary: healthSummary || '<li class="empty">No health data yet</li>',
    threadCount: threads.length.toString(),
    peopleCount: people.length.toString(),
    commitmentCount: activeCommitments.length.toString(),
  });
});

// Thread detail
app.get('/thread/:slug', (req, res) => {
  const filePath = path.join(opts.brain, 'threads', `${req.params.slug}.md`);
  const doc = readMarkdownFile(filePath);
  if (!doc.exists) {
    return res.status(404).send('Thread not found');
  }
  render(res, 'entity.html', {
    title: req.params.slug,
    entityType: 'Thread',
    entityName: req.params.slug,
    content: doc.html,
  });
});

// Person detail
app.get('/person/:slug', (req, res) => {
  const filePath = path.join(opts.brain, 'people', `${req.params.slug}.md`);
  const doc = readMarkdownFile(filePath);
  if (!doc.exists) {
    return res.status(404).send('Person not found');
  }
  const displayName = req.params.slug.replace(/-/g, ' ');
  render(res, 'entity.html', {
    title: displayName,
    entityType: 'Person',
    entityName: displayName,
    content: doc.html,
  });
});

// Timeline
app.get('/timeline', (req, res) => {
  const handoff = readMarkdownFile(path.join(opts.brain, 'handoff.md'));

  // Parse handoff entries into individual sections
  const entries = [];
  const sections = handoff.raw.split(/^## /m).slice(1); // skip preamble
  for (const section of sections) {
    const lines = section.split('\n');
    const header = lines[0].trim();
    const body = lines.slice(1).join('\n').trim();
    const dateMatch = header.match(/^(\d{4}-\d{2}-\d{2})/);
    entries.push({
      date: dateMatch ? dateMatch[1] : '',
      title: header,
      html: renderMarkdown(body),
    });
  }

  const entriesHtml = entries.map(e =>
    `<div class="timeline-entry">
      <h3>${e.title}</h3>
      ${e.html}
    </div>`
  ).join('\n');

  render(res, 'timeline.html', {
    title: 'Timeline',
    entries: entriesHtml || '<p class="empty">No entries yet</p>',
  });
});

// Search
app.get('/search', (req, res) => {
  const query = req.query.q || '';
  let resultsHtml = '';

  if (query && db) {
    try {
      const results = db.prepare(`
        SELECT s.rowid, d.path, d.type,
               snippet(search_index, 0, '<mark>', '</mark>', '...', 32) as snippet
        FROM search_index s
        JOIN documents d ON d.id = s.rowid
        WHERE search_index MATCH ?
        ORDER BY rank
        LIMIT 20
      `).all(query);

      if (results.length > 0) {
        resultsHtml = results.map(r => {
          const name = path.basename(r.path, '.md');
          let href = '#';
          if (r.type === 'thread') href = `/thread/${name}`;
          else if (r.type === 'person') href = `/person/${name}`;

          return `<div class="search-result">
            <a href="${href}"><strong>${name}</strong></a>
            <span class="badge">${r.type}</span>
            <p>${r.snippet}</p>
          </div>`;
        }).join('\n');
      } else {
        resultsHtml = '<p class="empty">No results found</p>';
      }
    } catch (e) {
      resultsHtml = `<p class="error">Search error: ${e.message}</p>`;
    }
  } else if (query && !db) {
    resultsHtml = '<p class="error">Search index not available. Run indexer.py to build it.</p>';
  }

  render(res, 'search.html', {
    title: 'Search',
    query: query.replace(/"/g, '&quot;'),
    results: resultsHtml,
  });
});

// Meeting prep
app.get('/prep', (req, res) => {
  const prepDir = path.join(opts.brain, 'inbox', 'prep');
  let prepsHtml = '';

  if (fs.existsSync(prepDir)) {
    const files = fs.readdirSync(prepDir)
      .filter(f => f.endsWith('.md'))
      .sort()
      .reverse();

    if (files.length > 0) {
      prepsHtml = files.map(f => {
        const doc = readMarkdownFile(path.join(prepDir, f));
        return `<div class="timeline-entry">
          <div class="prep-filename">${f.replace('.md', '')}</div>
          ${doc.html}
        </div>`;
      }).join('\n');
    }
  }

  if (!prepsHtml) {
    prepsHtml = '<p class="empty">No prep packets generated yet. Run: <code>python3 scripts/generate-prep.py ~/brain</code></p>';
  }

  render(res, 'prep.html', {
    title: 'Meeting Prep',
    preps: prepsHtml,
  });
});

// Drafts (from background processor)
app.get('/drafts', (req, res) => {
  const draftsDir = path.join(opts.brain, 'inbox', 'drafts');
  let draftsHtml = '';

  if (fs.existsSync(draftsDir)) {
    // Get direct draft files (not in subdirs like follow-ups/)
    const files = fs.readdirSync(draftsDir)
      .filter(f => f.endsWith('.md'))
      .sort()
      .reverse();

    if (files.length > 0) {
      draftsHtml = files.map(f => {
        const doc = readMarkdownFile(path.join(draftsDir, f));
        return `<div class="timeline-entry">
          <div class="prep-filename">${f.replace('.md', '')}</div>
          ${doc.html}
        </div>`;
      }).join('\n');
    }
  }

  if (!draftsHtml) {
    draftsHtml = '<p class="empty">No drafts yet. The background processor generates these from inbox transcripts.</p>';
  }

  render(res, 'drafts.html', {
    title: 'Drafts',
    drafts: draftsHtml,
  });
});

// Follow-ups
app.get('/follow-ups', (req, res) => {
  const draftsDir = path.join(opts.brain, 'inbox', 'drafts', 'follow-ups');
  let draftsHtml = '';

  if (fs.existsSync(draftsDir)) {
    const files = fs.readdirSync(draftsDir)
      .filter(f => f.endsWith('.md'))
      .sort()
      .reverse();

    if (files.length > 0) {
      draftsHtml = files.map(f => {
        const doc = readMarkdownFile(path.join(draftsDir, f));
        return `<div class="timeline-entry">
          <div class="prep-filename">${f.replace('.md', '')}</div>
          ${doc.html}
        </div>`;
      }).join('\n');
    }
  }

  if (!draftsHtml) {
    draftsHtml = '<p class="empty">No follow-up drafts yet. Run: <code>python3 scripts/generate-followups.py ~/brain</code></p>';
  }

  render(res, 'followups.html', {
    title: 'Follow-Ups',
    drafts: draftsHtml,
  });
});

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------

app.listen(opts.port, () => {
  console.log(`Brain web UI running at http://localhost:${opts.port}`);
  console.log(`Reading from: ${opts.brain}`);
  console.log(`SQLite index: ${db ? 'connected' : 'not available'}`);
});
