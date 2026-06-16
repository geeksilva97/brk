// Black-box tests of a dojo's offline-jail hook (bash, shipped inside each
// dojo). We exercise demonkey's guard.sh as the representative. Skipped on
// Windows (the hooks are bash, and CI runs ubuntu + macos).
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { REPO_ROOT } from './helpers/env.js';

const skip = process.platform === 'win32';
const GUARD = path.join(REPO_ROOT, 'dojos', 'demonkey', 'hooks', 'guard.sh');
const PLUGIN_ROOT = path.join(REPO_ROOT, 'dojos', 'demonkey');

let project;
beforeEach(() => { project = fs.mkdtempSync(path.join(os.tmpdir(), 'dojo-guard-')); });
afterEach(() => fs.rmSync(project, { recursive: true, force: true }));

function guard(mode, payload) {
  return spawnSync('bash', [GUARD, mode], {
    input: payload,
    encoding: 'utf8',
    env: { ...process.env, CLAUDE_PLUGIN_ROOT: PLUGIN_ROOT, CLAUDE_PROJECT_DIR: project },
  });
}
const isDeny = (out) => /"permissionDecision"\s*:\s*"deny"/.test(out);

test('web mode always denies', { skip }, () => {
  assert.ok(isDeny(guard('web', '{}').stdout));
});

test('bash mode denies external HTTP egress but allows localhost', { skip }, () => {
  const evil = JSON.stringify({ tool_input: { command: 'curl https://evil.example.com/x' } });
  assert.ok(isDeny(guard('bash', evil).stdout), 'external host should be denied');

  const local = JSON.stringify({ tool_input: { command: 'curl http://localhost:8080/' } });
  assert.equal(guard('bash', local).stdout.trim(), '', 'localhost should be allowed (no output)');
});

test('bash mode denies ad-hoc gem installs', { skip }, () => {
  const payload = JSON.stringify({ tool_input: { command: 'gem install sinatra' } });
  assert.ok(isDeny(guard('bash', payload).stdout));
});

test('spine mode denies writing the current spine file, allows glue files', { skip }, () => {
  // Ask the dojo's own state helper what this step's spine is.
  const spine = spawnSync('bash', [path.join(PLUGIN_ROOT, 'bin', 'dojo.sh'), 'spine'], {
    encoding: 'utf8',
    env: { ...process.env, CLAUDE_PLUGIN_ROOT: PLUGIN_ROOT, CLAUDE_PROJECT_DIR: project },
  }).stdout.trim();
  assert.ok(spine && spine !== '-', `expected a real spine file, got '${spine}'`);

  const writeSpine = JSON.stringify({ tool_input: { file_path: spine } });
  assert.ok(isDeny(guard('spine', writeSpine).stdout), 'spine write should be denied');

  const writeGlue = JSON.stringify({ tool_input: { file_path: 'workspace/some_glue_helper.rb' } });
  assert.equal(guard('spine', writeGlue).stdout.trim(), '', 'glue write should be allowed');
});