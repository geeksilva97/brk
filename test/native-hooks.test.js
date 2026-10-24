import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { REPO_ROOT } from './helpers/env.js';

const binary = process.env.BRK_TEST_BIN;
const skip = !binary || process.platform === 'win32';
const dojos = ['demonkey', 'c10k-dojo', 'reactor-dojo', 'replicant', 'loopcraft', 'systeminterview'];

function sandbox(t) {
  // Compare hook text using one physical path: macOS TMPDIR may start with /var,
  // while the native runtime canonicalizes the same directory to /private/var.
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'brk-hooks-')));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

function hook(dojo, project, name, native, cwd = project) {
  const root = path.join(REPO_ROOT, 'dojos', dojo);
  const env = { ...process.env, CLAUDE_PLUGIN_ROOT: root, CLAUDE_PROJECT_DIR: project };
  if (native) env.BRK_RUNTIME_BIN = binary;
  else delete env.BRK_RUNTIME_BIN;
  return spawnSync('bash', [path.join(root, 'hooks', `${name}.sh`)], { cwd, env, encoding: 'utf8', input: '{}' });
}

for (const dojo of dojos) {
  test(`${dojo}: native context and title preserve standalone hook output`, { skip }, (t) => {
    const project = sandbox(t);
    const config = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'dojos', dojo, 'brk.json'), 'utf8'));
    const titleBefore = hook(dojo, project, 'title', true);
    assert.equal(titleBefore.status, 0, titleBefore.stderr);
    assert.equal(titleBefore.stdout, '');
    assert.equal(fs.existsSync(path.join(project, config.state_dir)), false);
    const legacy = hook(dojo, project, 'session-start', false);
    const native = hook(dojo, project, 'session-start', true);
    assert.equal(legacy.status, 0, legacy.stderr);
    assert.equal(native.status, 0, native.stderr);
    assert.deepEqual(JSON.parse(native.stdout), JSON.parse(legacy.stdout));
    assert.equal(hook(dojo, project, 'title', true).stdout, '');
    const cache = path.join(project, config.state_dir, '.titled_step');
    fs.rmSync(cache);
    const legacyTitle = hook(dojo, project, 'title', false);
    fs.rmSync(cache);
    const nativeTitle = hook(dojo, project, 'title', true);
    assert.deepEqual(JSON.parse(nativeTitle.stdout), JSON.parse(legacyTitle.stdout));
    // A setup sentinel removes the prefix identically in both implementations.
    fs.writeFileSync(path.join(project, config.state_dir, '.setup_done'), '');
    assert.deepEqual(JSON.parse(hook(dojo, project, 'session-start', true).stdout), JSON.parse(hook(dojo, project, 'session-start', false).stdout));
  });
}

test('native SessionStart resolves a symlinked project to the same state and context', { skip }, (t) => {
  const root = sandbox(t);
  const project = path.join(root, 'physical project');
  const alias = path.join(root, 'project alias');
  fs.mkdirSync(project);
  fs.symlinkSync(project, alias, 'dir');

  const native = hook('replicant', alias, 'session-start', true);
  assert.equal(native.status, 0, native.stderr);
  const legacy = hook('replicant', project, 'session-start', false);
  assert.equal(legacy.status, 0, legacy.stderr);
  assert.deepEqual(JSON.parse(native.stdout), JSON.parse(legacy.stdout));
  assert.equal(
    fs.realpathSync(path.join(alias, '.replicant', 'progress.json')),
    path.join(project, '.replicant', 'progress.json'),
  );
  assert.equal(hook('replicant', alias, 'title', true).stdout, '');
});

test('native hooks read top-level state and safely serialize quotes and backslashes', { skip }, (t) => {
  const root = sandbox(t);
  const project = path.join(root, 'project "quoted" \\ path');
  fs.mkdirSync(path.join(project, '.replicant'), { recursive: true });
  const mode = 'custom "quoted" \\ mode\n${step} stays literal';
  const progress = path.join(project, '.replicant', 'progress.json');
  const raw = JSON.stringify({ future: { step: 6, mode: 'wrong', spine_file: 'wrong' }, step: 2, completed: [1], mode, spine_file: 'workspace/framing.rb' });
  fs.writeFileSync(progress, raw);
  const result = hook('replicant', project, 'session-start', true);
  assert.equal(result.status, 0, result.stderr);
  const output = JSON.parse(result.stdout).hookSpecificOutput;
  assert.match(output.sessionTitle, /Step 2:/);
  assert.ok(output.additionalContext.includes(mode));
  assert.ok(output.additionalContext.includes(project));
  assert.ok(output.additionalContext.includes('workspace/framing.rb'));
  assert.equal(fs.readFileSync(progress, 'utf8'), raw);
});

test('native SessionStart uses explicit project for setup checks instead of cwd', { skip }, (t) => {
  const root = sandbox(t);
  const project = path.join(root, 'project');
  fs.mkdirSync(path.join(project, 'docs'), { recursive: true });
  fs.mkdirSync(path.join(project, 'workspace'));
  fs.writeFileSync(path.join(project, 'docs', 'INDEX.md'), '# Offline');
  const result = hook('replicant', project, 'session-start', true, root);
  assert.equal(result.status, 0, result.stderr);
  assert.ok(!JSON.parse(result.stdout).hookSpecificOutput.additionalContext.includes('FIRST ACTION'));
});

test('native SessionStart never resets progress when racing native advances', { skip }, async (t) => {
  const project = sandbox(t);
  const plugin = path.join(REPO_ROOT, 'dojos', 'replicant');
  const run = (args) => new Promise((resolve, reject) => {
    const child = spawn(binary, args, { stdio: ['ignore', 'ignore', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (data) => { stderr += data; });
    child.on('error', reject);
    child.on('close', (code) => code === 0 ? resolve() : reject(new Error(stderr)));
  });
  await Promise.all([
    ...Array.from({ length: 8 }, () => run(['hook', 'session-start', '--plugin-root', plugin, '--project-dir', project])),
    ...Array.from({ length: 8 }, () => run(['state', '--plugin-root', plugin, '--project-dir', project, 'advance'])),
  ]);
  const progress = JSON.parse(fs.readFileSync(path.join(project, '.replicant', 'progress.json'), 'utf8'));
  assert.equal(progress.step, 9);
  assert.deepEqual(progress.completed, [1, 2, 3, 4, 5, 6, 7, 8]);
});

test('native hook bootstrap refuses malformed existing progress without replacing it', { skip }, (t) => {
  const project = sandbox(t);
  fs.mkdirSync(path.join(project, '.replicant'));
  const progress = path.join(project, '.replicant', 'progress.json');
  const raw = '{"step":';
  fs.writeFileSync(progress, raw);
  const result = hook('replicant', project, 'session-start', true);
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
  assert.equal(fs.readFileSync(progress, 'utf8'), raw);
});
