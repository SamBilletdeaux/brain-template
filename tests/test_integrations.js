#!/usr/bin/env node
/**
 * Integration module tests — verifies modules load and behave correctly
 * without live services. No env vars needed.
 *
 * Run: node tests/test_integrations.js
 */

const path = require('path');

let pass = 0;
let fail = 0;

function assert(condition, desc) {
  if (condition) {
    console.log(`  PASS: ${desc}`);
    pass++;
  } else {
    console.log(`  FAIL: ${desc}`);
    fail++;
  }
}

// --- Slack module ---
console.log('=== Test: Slack module ===');

// Clear env vars to test unconfigured state
delete process.env.SLACK_BOT_TOKEN;
delete process.env.SLACK_SIGNING_SECRET;
delete process.env.SLACK_APP_TOKEN;

const { createSlackApp } = require(path.join(__dirname, '..', 'web', 'integrations', 'slack'));
assert(typeof createSlackApp === 'function', 'createSlackApp is a function');

const slackResult = createSlackApp('/tmp/fake-brain', null, (s) => s);
assert(slackResult === null, 'Returns null without env vars (graceful)');

// --- Email module ---
console.log('\n=== Test: Email module ===');

delete process.env.BRAIN_EMAIL_HOST;
delete process.env.BRAIN_EMAIL_USER;
delete process.env.BRAIN_EMAIL_PASS;

const { EmailWatcher } = require(path.join(__dirname, '..', 'web', 'integrations', 'email'));
assert(typeof EmailWatcher === 'function', 'EmailWatcher is a constructor');

const watcher = new EmailWatcher('/tmp/fake-brain');
assert(typeof watcher.canStart === 'function', 'canStart method exists');
assert(watcher.canStart() === false, 'canStart returns false without env vars');
assert(typeof watcher.getStatus === 'function', 'getStatus method exists');

const status = watcher.getStatus();
assert(status.connected === false, 'Status shows not connected');
assert(status.watching === false, 'Status shows not watching');
assert(status.messagesProcessed === 0, 'Status shows 0 messages processed');
assert(status.lastError === null, 'Status shows no errors');

// --- Summary ---
console.log(`\n===========================`);
console.log(`Results: ${pass} passed, ${fail} failed`);
console.log(`===========================`);

process.exit(fail > 0 ? 1 : 0);
