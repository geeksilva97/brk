// Differential tests keep the shell helpers as the migration's reference oracle.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { REPO_ROOT, makeEnv, runCli } from './helpers/env.js';
import { WATCH_LOOP_PROMPT } from '../src/lib/watch.js';

const binary = process.env.BRK_TEST_BIN;
const skip = !binary || process.platform === 'win32';
const dojos = ['demonkey', 'c10k-dojo', 'reactor-dojo', 'loopcraft', 'replicant', 'systeminterview'];

function sandbox(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'brk-state-contract-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

function state(dojo, project, args, native) {
  const plugin = path.join(REPO_ROOT, 'dojos', dojo);
  const env = { ...process.env, CLAUDE_PLUGIN_ROOT: plugin, CLAUDE_PROJECT_DIR: project };
  if (native) env.BRK_RUNTIME_BIN = binary;
  else delete env.BRK_RUNTIME_BIN;
  return spawnSync('bash', [path.join(plugin, 'bin', 'dojo.sh'), ...args], {
    encoding: 'utf8', env,
  });
}

for (const dojo of dojos) {
  test(`${dojo}: native state matches standalone shell at every curriculum step`, { skip }, (t) => {
    const root = sandbox(t);
    const legacy = path.join(root, 'legacy');
    const native = path.join(root, 'native');
    fs.mkdirSync(legacy);
    fs.mkdirSync(native);
    const rows = fs.readFileSync(path.join(REPO_ROOT, 'dojos', dojo, 'curriculum', 'steps.tsv'), 'utf8').trim().split('\n');
    for (let step = 1; step <= rows.length; step++) {
      const commands = [['get'], ['title'], ['mode'], ['status']];
      if (dojo !== 'systeminterview') commands.push(['spine'], ['kind']);
      for (const args of commands) {
        const expected = state(dojo, legacy, args, false);
        const actual = state(dojo, native, args, true);
        assert.equal(expected.status, 0, expected.stderr);
        assert.equal(actual.status, expected.status, `${dojo} ${args}: ${actual.stderr}`);
        if (args[0] === 'status') assert.deepEqual(JSON.parse(actual.stdout), JSON.parse(expected.stdout));
        else assert.equal(actual.stdout, expected.stdout, `${dojo} step ${step}: ${args}`);
      }
      if (step < rows.length) {
        const expected = state(dojo, legacy, ['advance'], false);
        const actual = state(dojo, native, ['advance'], true);
        assert.equal(actual.status, expected.status, actual.stderr);
        assert.equal(actual.stdout, expected.stdout);
      }
    }
  });
}

test('native state preserves arbitrary modes, extra fields and compact legacy JSON', { skip }, (t) => {
  const project = sandbox(t);
  const dir = path.join(project, '.systeminterview');
  fs.mkdirSync(dir);
  const progress = path.join(dir, 'progress.json');
  const raw = '{"step":1,"completed":[],"mode":"interview","future":{"notes":["keep me"]}}';
  fs.writeFileSync(progress, raw);
  assert.equal(state('systeminterview', project, ['status'], true).stdout, raw);
  const mode = 'custom "quoted" \\ mode\nsecond line';
  assert.equal(state('systeminterview', project, ['set-mode', mode], true).status, 0);
  assert.equal(state('systeminterview', project, ['advance'], true).status, 0);
  const result = JSON.parse(fs.readFileSync(progress, 'utf8'));
  assert.equal(result.mode, mode);
  assert.deepEqual(result.future, { notes: ['keep me'] });
  assert.equal(result.step, 2);
});

test('malformed state and advancing past final step never overwrite progress', { skip }, (t) => {
  const project = sandbox(t);
  const dir = path.join(project, '.replicant');
  fs.mkdirSync(dir);
  const progress = path.join(dir, 'progress.json');
  for (const raw of ['{"step":', '{"step":20,"completed":[],"mode":"local-jailed","spine_file":"workspace/node.rb"}']) {
    fs.writeFileSync(progress, raw);
    const result = state('replicant', project, ['advance'], true);
    assert.notEqual(result.status, 0);
    assert.equal(fs.readFileSync(progress, 'utf8'), raw);
  }
});

test('concurrent native advances preserve every completed step', { skip }, async (t) => {
  const project = sandbox(t);
  const plugin = path.join(REPO_ROOT, 'dojos', 'replicant');
  const advance = () => new Promise((resolve, reject) => {
    const child = spawn(binary, ['state', '--plugin-root', plugin, '--project-dir', project, 'advance'], {
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    let stderr = '';
    child.stderr.on('data', (data) => { stderr += data; });
    child.on('error', reject);
    child.on('close', (code) => code === 0 ? resolve() : reject(new Error(stderr)));
  });
  await Promise.all(Array.from({ length: 8 }, advance));
  const result = JSON.parse(fs.readFileSync(path.join(project, '.replicant', 'progress.json'), 'utf8'));
  assert.equal(result.step, 9);
  assert.deepEqual(result.completed, [1, 2, 3, 4, 5, 6, 7, 8]);
});

test('watch prompt remains byte-for-byte compatible and native sessions receive the runtime', { skip }, (t) => {
  const sb = makeEnv();
  t.after(sb.cleanup);
  const result = runCli(['run', '--watch', 'replicant'], sb.env);
  assert.equal(result.status, 0, result.stderr);
  const call = sb.calls()[0];
  assert.equal(call.argv.find((arg) => arg.startsWith('/loop')), WATCH_LOOP_PROMPT);
  assert.equal(fs.realpathSync(call.runtime), fs.realpathSync(binary));
});

test('existing hooks read native progress and guard the current spine', { skip }, (t) => {
  const project = sandbox(t);
  const plugin = path.join(REPO_ROOT, 'dojos', 'replicant');
  const env = { ...process.env, BRK_RUNTIME_BIN: binary, CLAUDE_PLUGIN_ROOT: plugin, CLAUDE_PROJECT_DIR: project };
  assert.equal(state('replicant', project, ['advance'], true).status, 0);
  const session = spawnSync('bash', [path.join(plugin, 'hooks', 'session-start.sh')], {
    cwd: project, encoding: 'utf8', env, input: '{}',
  });
  assert.equal(session.status, 0, session.stderr);
  const context = JSON.parse(session.stdout).hookSpecificOutput;
  assert.match(context.sessionTitle, /Step 2/);
  const guard = spawnSync('bash', [path.join(plugin, 'hooks', 'guard.sh'), 'spine'], {
    cwd: project, encoding: 'utf8', env,
    input: JSON.stringify({ tool_input: { file_path: path.join(project, 'workspace', 'framing.rb') } }),
  });
  assert.equal(guard.status, 0, guard.stderr);
  assert.equal(JSON.parse(guard.stdout).hookSpecificOutput.permissionDecision, 'deny');
  assert.equal(state('replicant', project, ['advance'], true).status, 0);
  const title = spawnSync('bash', [path.join(plugin, 'hooks', 'title.sh')], {
    cwd: project, encoding: 'utf8', env, input: '{}',
  });
  assert.equal(title.status, 0, title.stderr);
  assert.match(JSON.parse(title.stdout).hookSpecificOutput.sessionTitle, /Step 3/);
});

test('native-launched tutor can use the existing dojo.sh entrypoint', { skip }, (t) => {
  const sb = makeEnv();
  t.after(sb.cleanup);
  const stub = path.join(sb.dir, 'state-tutor.cjs');
  fs.writeFileSync(stub, `#!/usr/bin/env node
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const args = process.argv.slice(2);
const root = args[args.indexOf('--plugin-dir') + 1];
const result = spawnSync('bash', [path.join(root, 'bin/dojo.sh'), 'get'], { encoding: 'utf8', env: { ...process.env, CLAUDE_PLUGIN_ROOT: root, CLAUDE_PROJECT_DIR: process.cwd() } });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
process.exit(result.status ?? 1);
`, { mode: 0o755 });
  const project = path.join(sb.dir, 'new project');
  const result = runCli(['run', 'replicant', project], sb.env, { BRK_CLAUDE_BIN: stub });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '1\n');
  assert.ok(fs.existsSync(path.join(project, '.replicant', 'progress.lock')));
});
