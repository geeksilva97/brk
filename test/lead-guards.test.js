// Black-box tests of the lead-mode jail (replicant-lead's guard.sh and post-trial.sh). Lead mode
// inverts build mode: the agent may write everything, but only in order — decide, then build;
// commit to expected results, then run the trial. Skipped on Windows (the hooks are bash).
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { REPO_ROOT } from './helpers/env.js';

const skip = process.platform === 'win32';
const PLUGIN_ROOT = path.join(REPO_ROOT, 'dojos', 'replicant-lead');
const GUARD = path.join(PLUGIN_ROOT, 'hooks', 'guard.sh');
const POST_TRIAL = path.join(PLUGIN_ROOT, 'hooks', 'post-trial.sh');
const ADR = 'decisions/013-read-gate.md';
const SECTIONS = ['Context', 'Decision', 'Alternatives', 'Consequences', 'Failure modes'];

let project;
beforeEach(() => { project = fs.mkdtempSync(path.join(os.tmpdir(), 'dojo-lead-guard-')); });
afterEach(() => fs.rmSync(project, { recursive: true, force: true }));

function run(script, args, payload) {
  return spawnSync('bash', [script, ...args], {
    input: payload,
    encoding: 'utf8',
    env: { ...process.env, CLAUDE_PLUGIN_ROOT: PLUGIN_ROOT, CLAUDE_PROJECT_DIR: project },
  });
}
const guard = (mode, payload) => run(GUARD, [mode], JSON.stringify(payload)).stdout;
const isDeny = (out) => /"permissionDecision"\s*:\s*"deny"/.test(out);

function writeAdr(expectedItems) {
  const body = SECTIONS.map((s) => `## ${s}\nx\n`).join('')
    + (expectedItems === undefined ? '' : `## Expected results\n${expectedItems.map((i) => `- ${i}`).join('\n')}\n`);
  fs.mkdirSync(path.join(project, 'decisions'), { recursive: true });
  fs.writeFileSync(path.join(project, ADR), body);
}

const codeWrite = () => ({ tool_input: { file_path: path.join(project, 'workspace', 'lib', 'client.rb') } });
const trial = { tool_input: { command: `"${PLUGIN_ROOT}/bin/trial.sh" 13` } };

test('a new project starts at the first row of steps.tsv, a lead step', { skip }, () => {
  const step = run(path.join(PLUGIN_ROOT, 'bin', 'dojo.sh'), ['get']).stdout.trim();
  const kind = run(path.join(PLUGIN_ROOT, 'bin', 'dojo.sh'), ['kind']).stdout.trim();
  assert.equal(step, '13');
  assert.equal(kind, 'lead');
});

test('the agent may write the ADR — it is the scribe', { skip }, () => {
  assert.equal(guard('spine', { tool_input: { file_path: path.join(project, ADR) } }), '');
});

test('no workspace code before the ADR exists', { skip }, () => {
  assert.ok(isDeny(guard('spine', codeWrite())));
});

test('no workspace code while an ADR section is missing', { skip }, () => {
  writeAdr(undefined);
  assert.ok(isDeny(guard('spine', codeWrite())));
});

test('no workspace code while an expected result has no number', { skip }, () => {
  writeAdr(['stale without the gate: 90', 'stale with the gate: low']);
  assert.ok(isDeny(guard('spine', codeWrite())));
});

test('workspace code is allowed once the ADR is complete', { skip }, () => {
  writeAdr(['stale without the gate: 90', 'stale with the gate: 0']);
  assert.equal(guard('spine', codeWrite()), '');
});

test('the GIVEN harness and the plugin are never writable', { skip }, () => {
  writeAdr(['stale with the gate: 0']);
  for (const fp of [
    path.join(project, 'workspace', 'bin', 'link'),
    path.join(project, 'workspace', 'lib', 'wire.rb'),
    path.join(PLUGIN_ROOT, 'env', 'trial', 'step-13.rb'),
  ]) {
    assert.ok(isDeny(guard('spine', { tool_input: { file_path: fp } })), `${fp} should be denied`);
  }
});

test('the trial is blocked until expected results are numbered; the repro never is', { skip }, () => {
  assert.ok(isDeny(guard('bash', trial)));
  const repro = { tool_input: { command: `"${PLUGIN_ROOT}/bin/trial.sh" 13 --repro` } };
  assert.equal(guard('bash', repro), '');
  writeAdr(['stale with the gate: 0']);
  assert.equal(guard('bash', trial), '');
});

test('post-trial records the result and pairs it with the expected results', { skip }, () => {
  writeAdr(['stale with the gate: 0']);
  const payload = JSON.stringify({ tool_response: { stdout: 'noise\nTRIAL_RESULT,step=13,gate_stale=0/100,partition=fresh@1532ms\n' } });
  const out = run(POST_TRIAL, [], payload).stdout;
  const ctx = JSON.parse(out).hookSpecificOutput.additionalContext;
  assert.match(ctx, /MEASURED: step=13,gate_stale=0\/100,partition=fresh@1532ms/);
  assert.match(ctx, /LEARNER EXPECTED .*stale with the gate: 0/);
  const csv = fs.readFileSync(path.join(project, '.replicant-lead', 'results.csv'), 'utf8');
  assert.match(csv, /step=13,gate_stale=0\/100/);
});

test('post-trial is a no-op for ordinary commands', { skip }, () => {
  assert.equal(run(POST_TRIAL, [], JSON.stringify({ tool_response: { stdout: 'ok' } })).stdout, '');
});

const dojo = (...args) => run(path.join(PLUGIN_ROOT, 'bin', 'dojo.sh'), args).stdout.trim();
const sessionContext = () =>
  JSON.parse(run(path.join(PLUGIN_ROOT, 'hooks', 'session-start.sh'), []).stdout).hookSpecificOutput.additionalContext;

test('drill mode is an instructor toggle that session-start passes to the agent', { skip }, () => {
  assert.equal(dojo('drill'), 'off');
  assert.doesNotMatch(sessionContext(), /DRILL MODE/);
  assert.equal(dojo('drill', 'on'), 'on');
  assert.match(sessionContext(), /DRILL MODE IS ON/);
  assert.equal(dojo('drill', 'off'), 'off');
  assert.doesNotMatch(sessionContext(), /DRILL MODE/);
});

test('session-start sends a fresh project to setup first', { skip }, () => {
  assert.match(sessionContext(), /^FIRST ACTION.*setup/);
  fs.writeFileSync(path.join(project, '.replicant-lead', '.setup_done'), '');
  assert.doesNotMatch(sessionContext(), /FIRST ACTION/);
});

test('the title hook renames only when the step changes', { skip }, () => {
  const title = () => run(path.join(PLUGIN_ROOT, 'hooks', 'title.sh'), [], '{}').stdout;
  assert.equal(title(), '', 'no-op outside a started dojo');
  dojo('get');
  assert.match(JSON.parse(title()).hookSpecificOutput.sessionTitle, /^replicant-lead - Step 13: /);
  assert.equal(title(), '', 'no rename while the step is unchanged');
});

test('advance on the last step stays put and says so', { skip }, () => {
  assert.match(dojo('advance'), /last one/);
  assert.equal(dojo('get'), '13');
  assert.match(dojo('status'), /"completed": \[13\]/);
});

test('numbered expected results count too, but the list marker is not a number', { skip }, () => {
  const write = (lines) => {
    fs.mkdirSync(path.join(project, 'decisions'), { recursive: true });
    fs.writeFileSync(path.join(project, ADR),
      SECTIONS.map((s) => `## ${s}\nx\n`).join('') + `## Expected results\n${lines.join('\n')}\n`);
  };
  write(['1. stale without the gate: 90', '2) stale with the gate: low']);
  assert.ok(isDeny(guard('spine', codeWrite())), '"2) ... low" has no number once the marker is stripped');
  write(['1. stale without the gate: 90', '2) stale with the gate: 0']);
  assert.equal(guard('spine', codeWrite()), '');
});
