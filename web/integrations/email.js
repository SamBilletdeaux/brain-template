/**
 * Email integration for Brain
 *
 * Provides:
 * - IMAP watcher: monitors a mailbox for forwarded emails, saves to inbox
 * - Weekly digest: generates and sends a summary of brain activity
 * - Follow-up mailto links: creates clickable email links from drafts
 *
 * Environment variables:
 *   BRAIN_EMAIL_HOST     — IMAP server (e.g., imap.gmail.com)
 *   BRAIN_EMAIL_PORT     — IMAP port (default: 993)
 *   BRAIN_EMAIL_USER     — Email address
 *   BRAIN_EMAIL_PASS     — App password (not your regular password)
 *   BRAIN_EMAIL_MAILBOX  — Mailbox to watch (default: Brain)
 *
 * For Gmail:
 *   1. Create a label called "Brain"
 *   2. Create a filter: forward emails to yourself with label "Brain"
 *   3. Generate an app password at myaccount.google.com/apppasswords
 *   4. Set env vars above
 *
 * Or simply forward emails to your address with "brain:" in the subject.
 */

const fs = require('fs');
const path = require('path');
const { Readable } = require('stream');

let Imap, simpleParser;
try {
  Imap = require('imap');
  simpleParser = require('mailparser').simpleParser;
} catch (e) {
  // Email packages not installed — that's fine, integration is optional
}

class EmailWatcher {
  constructor(brainRoot) {
    this.brainRoot = brainRoot;
    this.imap = null;
    this.watching = false;
  }

  canStart() {
    if (!Imap || !simpleParser) {
      console.log('Email: imap and mailparser not installed. Run: npm install imap mailparser');
      return false;
    }
    if (!process.env.BRAIN_EMAIL_HOST || !process.env.BRAIN_EMAIL_USER || !process.env.BRAIN_EMAIL_PASS) {
      console.log('Email: BRAIN_EMAIL_HOST, BRAIN_EMAIL_USER, BRAIN_EMAIL_PASS not set, skipping');
      return false;
    }
    return true;
  }

  start() {
    if (!this.canStart()) return;

    this.imap = new Imap({
      user: process.env.BRAIN_EMAIL_USER,
      password: process.env.BRAIN_EMAIL_PASS,
      host: process.env.BRAIN_EMAIL_HOST,
      port: parseInt(process.env.BRAIN_EMAIL_PORT || '993', 10),
      tls: true,
      tlsOptions: { rejectUnauthorized: false },
    });

    this.imap.on('ready', () => {
      console.log('Email: connected');
      this.watchMailbox();
    });

    this.imap.on('error', (err) => {
      console.error('Email: IMAP error —', err.message);
    });

    this.imap.on('end', () => {
      console.log('Email: disconnected');
      // Reconnect after 30 seconds
      if (this.watching) {
        setTimeout(() => this.start(), 30000);
      }
    });

    this.imap.connect();
    this.watching = true;
  }

  stop() {
    this.watching = false;
    if (this.imap) {
      this.imap.end();
    }
  }

  watchMailbox() {
    const mailbox = process.env.BRAIN_EMAIL_MAILBOX || 'Brain';

    this.imap.openBox(mailbox, false, (err, box) => {
      if (err) {
        // Try INBOX if custom mailbox doesn't exist
        console.log(`Email: "${mailbox}" not found, watching INBOX`);
        this.imap.openBox('INBOX', false, (err2, box2) => {
          if (err2) {
            console.error('Email: could not open mailbox —', err2.message);
            return;
          }
          this.processUnread();
          this.listenForNew();
        });
        return;
      }

      this.processUnread();
      this.listenForNew();
    });
  }

  listenForNew() {
    this.imap.on('mail', () => {
      this.processUnread();
    });
  }

  processUnread() {
    this.imap.search(['UNSEEN'], (err, results) => {
      if (err || !results || results.length === 0) return;

      const fetch = this.imap.fetch(results, { bodies: '', markSeen: true });

      fetch.on('message', (msg) => {
        let buffer = '';

        msg.on('body', (stream) => {
          stream.on('data', (chunk) => {
            buffer += chunk.toString('utf8');
          });

          stream.on('end', () => {
            this.parseAndSave(buffer);
          });
        });
      });
    });
  }

  async parseAndSave(rawEmail) {
    try {
      const parsed = await simpleParser(rawEmail);

      const subject = parsed.subject || 'No subject';
      const from = parsed.from ? parsed.from.text : 'unknown';
      const date = parsed.date ? parsed.date.toISOString() : new Date().toISOString();
      const text = parsed.text || '';
      const html = parsed.html || '';

      // Use text content, fall back to stripping HTML
      let body = text;
      if (!body && html) {
        body = html.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
      }

      // Save to inbox
      const inboxDir = path.join(this.brainRoot, 'inbox', 'email');
      fs.mkdirSync(inboxDir, { recursive: true });

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const slug = subject.toLowerCase().replace(/[^a-z0-9]+/g, '-').slice(0, 40);
      const filename = `${timestamp}-${slug}.md`;

      const content = [
        '---',
        `source: email`,
        `subject: ${subject}`,
        `from: ${from}`,
        `date: ${date}`,
        '---',
        '',
        body,
      ].join('\n');

      fs.writeFileSync(path.join(inboxDir, filename), content);
      console.log(`Email: saved ${filename}`);
    } catch (e) {
      console.error('Email: parse error —', e.message);
    }
  }
}

/**
 * Generate a mailto: link for a follow-up draft
 */
function followUpMailtoLink(draft) {
  const subjectMatch = draft.match(/\*\*Subject\*\*:\s*(.+)/);
  const subject = subjectMatch
    ? subjectMatch[1].replace('[TODO — suggested: ', '').replace(']', '')
    : 'Follow-up';

  // Extract the draft message body
  const bodyMatch = draft.match(/## Draft Message\n\n([\s\S]*?)(?=\n---|\n##|$)/);
  let body = '';
  if (bodyMatch) {
    body = bodyMatch[1]
      .replace(/^>\s*/gm, '')  // remove blockquote markers
      .replace(/\*\*/g, '')     // remove bold markers
      .trim();
  }

  return `mailto:?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}

module.exports = { EmailWatcher, followUpMailtoLink };
