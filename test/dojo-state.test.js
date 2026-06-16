// The state helper bin/dojo.sh ships inside each dojo (bash). Verify the core
// get/advance/status flow against an isolated per-project state dir.
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { REPO_ROOT } from './helpers/env.js';

const skip = process.platform === 'win32';
const DOJOS = ['demonkey', 'c10k-dojo'];

let project;
beforeEach(() => { project = fs.mkdtempSync(path.join(os.tmpdir(), 'dojo-state-')); });
afterEach(() => fs.rmSync(project, { recursive: true, force: true }));

function state(dojo, args) {
  const root = path.join(REPO_ROOT, 'dojos', dojo);
  return spawnSync('bash', [path.join(root, 'bin', 'dojo.sh'), ...args], {
    encoding: 'utf8',
    env: { ...process.env, CLAUDE_PLUGIN_ROOT: root, CLAUDE_PROJECT_DIR: project },
  });
}

for (const dojo of DOJOS) {
  test(`${dojo}: fresh project starts at step 1`, { skip }, () => {
    assert.equal(state(dojo, ['get']).stdout.trim(), '1');
  });

  test(`${dojo}: status is valid JSON at step 1`, { skip }, () => {
    const json = JSON.parse(state(dojo, ['status']).stdout);
    assert.equal(json.step, 1);
  });

  test(`${dojo}: advance moves to step 2`, { skip }, () => {
    const adv = state(dojo, ['advance']);
    assert.match(adv.stdout, /step 2/);
    assert.equal(state(dojo, ['get']).stdout.trim(), '2');
  });
}