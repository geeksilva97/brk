// Native-only regressions: subprocess failures, offline caches, and path boundaries.
// Every executable stub and fixture lives in the disposable makeEnv sandbox.
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeEnv, runCli, REPO_ROOT } from './helpers/env.js';
import { makeFixtureRegistry } from './helpers/fixture-registry.js';

const skip = !process.env.BRK_TEST_BIN;
let sb;
let gitLog;

beforeEach(() => {
  sb = makeEnv();
  gitLog = path.join(sb.dir, 'git.log');
  // Fail closed: only local fixture setup temporarily enables real git.
  stubGit();
});
afterEach(() => sb.cleanup());

function writeStub(name, log, body) {
  const executable = path.join(sb.dir, 'bin', name);
  fs.writeFileSync(executable, `#!/usr/bin/env node
const fs = require('node:fs');
const argv = process.argv.slice(2);
fs.appendFileSync(${JSON.stringify(log)}, JSON.stringify({ argv, cwd: process.cwd() }) + '\\n');
${body}
`, { mode: 0o755 });
  return executable;
}

function stubGit() {
  return writeStub('git', gitLog, `
process.stderr.write('fixture git failure: no network allowed\\n');
process.exit(47);`);
}

function gitCalls() {
  if (!fs.existsSync(gitLog)) return [];
  return fs.readFileSync(gitLog, 'utf8').trim().split('\n').filter(Boolean)
    .map((line) => JSON.parse(line).argv);
}

const localOnlyGit = {
  GIT_ALLOW_PROTOCOL: 'file', GIT_TERMINAL_PROMPT: '0',
  GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: os.devNull,
  GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.hooksPath', GIT_CONFIG_VALUE_0: os.devNull,
};

function cloneFixture({ name = 'origin-a', dojo = 'dojo-a', alias = 'shared' } = {}) {
  // The shared fixture helper inherits process.env for its synchronous setup
  // commands. Isolate those as well as the CLI clone from user hooks/config.
  const previous = Object.fromEntries(Object.keys(localOnlyGit).map((key) => [key, process.env[key]]));
  let fixture;
  try {
    Object.assign(process.env, localOnlyGit);
    fixture = makeFixtureRegistry(sb.dir, { name, dojo });
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
  // No network or user-configured hooks during setup; all later operations
  // run against the fail-closed stub (including every update test).
  fs.rmSync(path.join(sb.dir, 'bin', 'git'));
  try {
    const added = runCli(['registry', 'add', fixture.repo, alias], sb.env, localOnlyGit);
    assert.equal(added.status, 0, added.stderr);
    const listed = runCli(['list'], sb.env, localOnlyGit);
    assert.equal(listed.status, 0, listed.stderr);
    assert.ok(listed.stdout.includes(dojo), listed.stdout);
  } finally {
    stubGit();
  }
  const cache = path.join(sb.cacheDir, alias);
  return { ...fixture, alias, cache, metadata: path.join(cache, '.git', 'brk-source.json') };
}

function stubLocalOrigin(origin, { allowPull = false } = {}) {
  writeStub('git', gitLog, `
if (argv[0] === 'config' && argv.includes('--file') && argv.includes('--no-includes')
    && argv.includes('--null') && argv.includes('--get-all')
    && argv.at(-1) === 'remote.origin.url') {
  process.stdout.write(${JSON.stringify(origin)} + '\\0');
  process.exit(0);
}
if (${allowPull} && argv.includes('pull')) process.exit(0);
process.stderr.write('fixture git failure: no network allowed\\n');
process.exit(47);`);
}

function assertUnavailable(fixture, pattern) {
  const listed = runCli(['list'], sb.env);
  assert.equal(listed.status, 0, listed.stderr);
  assert.match(listed.stdout, /unavailable/);
  assert.match(listed.stdout, pattern);
  assert.ok(!listed.stdout.includes(fixture.dojo), listed.stdout);
  const run = runCli(['run', fixture.dojo, path.join(sb.dir, 'workspace')], sb.env);
  assertFailed(run);
  assert.match(run.stderr, /unknown dojo/);
  assert.ok(!sb.calls().some((call) => call.argv[0] === '--plugin-dir'));
}

function assertFailed(result) {
  assert.ok(Number.isInteger(result.status) && result.status > 0,
    `expected a nonzero CLI exit, got ${result.status}\n${result.stdout}\n${result.stderr}`);
}

function assertNoInstalledSuccess(result) {
  assert.doesNotMatch(`${result.stdout}\n${result.stderr}`, /\b(?:un)?installed\s+demonkey@brk/i);
}

function seedConfig() {
  const file = path.join(sb.configDir, 'registries');
  const contents = `# keep this comment and whitespace\n\n${path.join(sb.dir, 'existing-registry')} existing\n`;
  fs.mkdirSync(sb.configDir, { recursive: true });
  fs.writeFileSync(file, contents);
  return { file, contents };
}

function makeAssets({ source = './relocated-dojo' } = {}) {
  const root = path.join(sb.dir, 'relocated assets');
  const dojoDir = path.join(root, 'relocated-dojo');
  fs.mkdirSync(path.join(root, '.claude-plugin'), { recursive: true });
  fs.mkdirSync(path.join(dojoDir, '.claude-plugin'), { recursive: true });
  fs.writeFileSync(path.join(root, '.claude-plugin', 'marketplace.json'), JSON.stringify({
    name: 'relocated',
    owner: { name: 'Test' },
    plugins: [{ name: 'relocated-dojo', source }],
  }));
  fs.writeFileSync(path.join(dojoDir, '.claude-plugin', 'plugin.json'), JSON.stringify({
    name: 'relocated-dojo', description: 'A relocated fixture dojo.', version: '0.0.1',
  }));
  return { root, dojoDir };
}

for (const command of ['install', 'uninstall']) {
  test(`native ${command}: missing BRK_CLAUDE_BIN fails without a success message`, { skip }, () => {
    const missing = path.join(sb.dir, 'missing executable');
    const r = runCli([command, 'demonkey'], sb.env, { BRK_CLAUDE_BIN: missing });
    assertFailed(r);
    assertNoInstalledSuccess(r);
    assert.ok(r.stderr.includes(missing), r.stderr);
    assert.deepEqual(sb.calls(), [], 'must not fall back to claude on PATH');
    assert.deepEqual(gitCalls(), []);
  });
}

test('native install: a failed marketplace add never attempts plugin install', { skip }, () => {
  const executable = writeStub('marketplace failure', sb.env.BRK_STUB_LOG, `
if (argv.slice(0, 3).join(' ') === 'plugin marketplace add') {
  process.stderr.write('fixture marketplace add failed\\n');
  process.exit(23);
}
process.exit(0);`);
  const r = runCli(['install', 'demonkey'], sb.env, { BRK_CLAUDE_BIN: executable });
  assertFailed(r);
  assertNoInstalledSuccess(r);
  assert.deepEqual(sb.calls().map((call) => call.argv), [
    ['plugin', 'marketplace', 'add', fs.realpathSync(REPO_ROOT)],
  ]);
  assert.deepEqual(gitCalls(), []);
});

test('native update: a failed git pull returns 1 without touching a real remote', { skip }, () => {
  const { root } = makeAssets();
  // The stub handles git; only checkout detection needs the .git directory.
  fs.mkdirSync(path.join(root, '.git'));
  const r = runCli(['update'], sb.env, { BRK_HOME: root });
  assert.equal(r.status, 1, `${r.stdout}\n${r.stderr}`);
  assert.match(`${r.stdout}\n${r.stderr}`, /fixture git failure/);
  assert.doesNotMatch(r.stdout, /relocated:\s+updated/);
  const calls = gitCalls();
  assert.equal(calls.length, 1);
  assert.ok(calls[0].includes('pull'), JSON.stringify(calls));
  assert.ok(calls[0].includes(fs.realpathSync(root)), JSON.stringify(calls));
});

test('native run: flags after -- pass through verbatim instead of enabling watch', { skip }, () => {
  const project = path.join(sb.dir, 'workspace with spaces');
  const extra = ['-w', '--watch', '--model', 'fixture-model', 'a prompt with spaces', '--'];
  const r = runCli(['run', 'demonkey', project, '--', ...extra], sb.env);
  assert.equal(r.status, 0, r.stderr);
  const calls = sb.calls();
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].argv, [
    '--plugin-dir', fs.realpathSync(path.join(REPO_ROOT, 'dojos', 'demonkey')),
    ...extra,
    '--disallowed-tools', 'WebSearch', 'WebFetch',
  ]);
  assert.equal(calls[0].cwd, fs.realpathSync(project));
  assert.ok(!calls[0].argv.some((arg) => arg.startsWith('/loop')));
});

test('native run: a positional argument after -- is not consumed as a project directory', { skip }, () => {
  const prompt = path.join(sb.dir, 'this is a prompt, not a workspace');
  const r = runCli(['run', 'demonkey', '--', prompt, '-w', '--watch'], sb.env);
  assert.equal(r.status, 0, r.stderr);
  const calls = sb.calls();
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].argv, [
    '--plugin-dir', fs.realpathSync(path.join(REPO_ROOT, 'dojos', 'demonkey')),
    prompt, '-w', '--watch',
    '--disallowed-tools', 'WebSearch', 'WebFetch',
  ]);
  assert.equal(calls[0].cwd, fs.realpathSync(process.cwd()));
  assert.equal(fs.existsSync(prompt), false);
});

for (const flag of ['--watch', '-w']) {
  test(`native run: ${flag} rejects systeminterview's interview modality`, { skip }, () => {
    const config = JSON.parse(fs.readFileSync(
      path.join(REPO_ROOT, 'dojos', 'systeminterview', 'brk.json'), 'utf8',
    ));
    assert.equal(config.modality, 'interview');
    const r = runCli(['run', flag, 'systeminterview', path.join(sb.dir, 'workspace')], sb.env);
    assertFailed(r);
    assert.match(r.stderr, /watch/);
    assert.match(r.stderr, /interview/);
    assert.deepEqual(sb.calls(), [], 'must reject before launching the plugin');
  });
}

for (const location of ['', '--upload-pack=unexpected-command']) {
  test(`native registry add: rejects invalid location ${JSON.stringify(location)}`, { skip }, () => {
    const { file, contents } = seedConfig();
    const r = runCli(['registry', 'add', location, 'candidate'], sb.env);
    assertFailed(r);
    assert.equal(fs.readFileSync(file, 'utf8'), contents);
    assert.deepEqual(gitCalls(), []);
  });
}

for (const name of ['.', '..', '../escape', 'a/b']) {
  test(`native registry add: rejects unsafe name ${JSON.stringify(name)} without changing config`, { skip }, () => {
    const { file, contents } = seedConfig();
    const r = runCli(['registry', 'add', path.join(sb.dir, 'candidate'), name], sb.env);
    assertFailed(r);
    assert.match(r.stderr, /name/i);
    assert.equal(fs.readFileSync(file, 'utf8'), contents);
    assert.deepEqual(gitCalls(), [], 'validate the name before fetching');
    const cached = fs.existsSync(sb.cacheDir) ? fs.readdirSync(sb.cacheDir) : [];
    assert.deepEqual(cached, [], 'must not create a cache entry');
  });
}

for (const name of ['brk', 'existing']) {
  test(`native registry add: rejects name collision ${JSON.stringify(name)} without changing config`, { skip }, () => {
    const { file, contents } = seedConfig();
    const r = runCli(['registry', 'add', path.join(sb.dir, 'different-origin'), name], sb.env);
    assertFailed(r);
    assert.equal(fs.readFileSync(file, 'utf8'), contents);
    assert.deepEqual(gitCalls(), [], 'validate collisions before fetching');
  });
}

test('native registry add: a derived name cannot collide with an existing alias', { skip }, () => {
  const { file, contents } = seedConfig();
  const r = runCli(['registry', 'add', path.join(sb.dir, 'different-origin', 'existing.git')], sb.env);
  assertFailed(r);
  assert.equal(fs.readFileSync(file, 'utf8'), contents);
  assert.deepEqual(gitCalls(), []);
});

test('native external registry: list and run use the cloned cache offline without invoking git', { skip }, () => {
  const { repo, name, dojo } = cloneFixture({ name: 'fakereg', dojo: 'mini-dojo', alias: 'fakereg' });
  const cached = path.join(sb.cacheDir, name, dojo);
  assert.ok(fs.existsSync(path.join(sb.cacheDir, name, '.git')), 'expected a real cache clone');
  assert.ok(fs.existsSync(cached));

  fs.renameSync(repo, `${repo}-offline`);
  stubGit();
  const listed = runCli(['list'], sb.env);
  assert.equal(listed.status, 0, listed.stderr);
  assert.ok(listed.stdout.includes(dojo), listed.stdout);
  assert.match(listed.stdout, /A tiny fixture dojo/);
  const run = runCli(['run', dojo, path.join(sb.dir, 'workspace')], sb.env);
  assert.equal(run.status, 0, run.stderr);
  const launches = sb.calls().filter((call) => call.argv[0] === '--plugin-dir');
  assert.equal(launches.length, 1);
  assert.equal(launches[0].argv[1], fs.realpathSync(cached));
  assert.deepEqual(gitCalls(), [], 'cached list/run must not even attempt git pull');
});

test('native cache identity: remove/add with a different origin never reuses or pulls the old cache', { skip }, () => {
  const fixture = cloneFixture();
  const originalMetadata = fs.readFileSync(fixture.metadata, 'utf8');
  const originalConfig = fs.readFileSync(path.join(fixture.cache, '.git', 'config'), 'utf8');
  const originalMarketplace = fs.readFileSync(path.join(fixture.cache, '.claude-plugin', 'marketplace.json'), 'utf8');
  const pending = path.join(fixture.cache, 'uncommitted-work');
  fs.writeFileSync(pending, 'keep my work\n');
  const originB = path.join(sb.dir, 'origin-b');
  assert.equal(runCli(['registry', 'remove', fixture.alias], sb.env).status, 0);
  assert.equal(runCli(['registry', 'add', originB, fixture.alias], sb.env).status, 0);

  assertUnavailable(fixture, /different registry location.*new registry alias.*manually move/);
  const { root } = makeAssets(); // update must not touch the real bundled remote either
  const update = runCli(['update'], sb.env, { BRK_HOME: root });
  assertFailed(update);
  assert.match(update.stdout, /shared: fetch failed.*different registry location/);
  assert.deepEqual(gitCalls(), [], 'reject the identity mismatch before any git process');
  assert.equal(fs.readFileSync(fixture.metadata, 'utf8'), originalMetadata);
  assert.equal(fs.readFileSync(path.join(fixture.cache, '.git', 'config'), 'utf8'), originalConfig);
  assert.equal(fs.readFileSync(path.join(fixture.cache, '.claude-plugin', 'marketplace.json'), 'utf8'), originalMarketplace);
  assert.equal(fs.readFileSync(pending, 'utf8'), 'keep my work\n');

  // Removing an alias is not destructive: re-adding the exact source works offline.
  assert.equal(runCli(['registry', 'remove', fixture.alias], sb.env).status, 0);
  assert.equal(runCli(['registry', 'add', fixture.repo, fixture.alias], sb.env).status, 0);
  const restored = runCli(['list'], sb.env);
  assert.ok(restored.stdout.includes(fixture.dojo), restored.stdout);
  assert.deepEqual(gitCalls(), []);
});

test('native cache identity: a marked cache checks changed origin before update, not on offline reads', { skip }, () => {
  const fixture = cloneFixture();
  const originalMetadata = fs.readFileSync(fixture.metadata, 'utf8');
  const config = path.join(fixture.cache, '.git', 'config');
  const originB = path.join(sb.dir, 'origin-b');
  fs.writeFileSync(config, fs.readFileSync(config, 'utf8').replace(fixture.repo, originB));
  const listed = runCli(['list'], sb.env);
  assert.ok(listed.stdout.includes(fixture.dojo), listed.stdout);
  assert.deepEqual(gitCalls(), [], 'marked offline reads need no git executable');

  stubLocalOrigin(originB);
  const { root } = makeAssets();
  const update = runCli(['update'], sb.env, { BRK_HOME: root });
  assertFailed(update);
  assert.match(update.stdout, /changed remote\.origin\.url/);
  assert.equal(gitCalls().length, 1);
  assert.ok(gitCalls().every((args) => args[0] === 'config'), 'must never pull the changed origin');
  assert.equal(fs.readFileSync(fixture.metadata, 'utf8'), originalMetadata);
});

test('native cache identity: matching update validates origin and explicitly pulls origin', { skip }, () => {
  const fixture = cloneFixture();
  const originalMetadata = fs.readFileSync(fixture.metadata, 'utf8');
  stubLocalOrigin(fixture.repo, { allowPull: true });
  const { root } = makeAssets();
  const update = runCli(['update'], sb.env, { BRK_HOME: root });
  assert.equal(update.status, 0, `${update.stdout}\n${update.stderr}`);
  assert.match(update.stdout, /shared: updated/);
  const calls = gitCalls();
  assert.equal(calls.length, 2);
  assert.equal(calls[0][0], 'config');
  assert.deepEqual(calls[1], ['-C', fixture.cache, 'pull', '--ff-only', '--quiet', 'origin']);
  assert.equal(fs.readFileSync(fixture.metadata, 'utf8'), originalMetadata);
});

test('native cache identity: a legacy JS clone migrates once using only its local origin', { skip }, () => {
  const fixture = cloneFixture();
  fs.unlinkSync(fixture.metadata); // old JS clones have no native sidecar
  fs.rmSync(path.join(sb.dir, 'bin', 'git'));
  try {
    // The source is gone: migration must only read .git/config, not fetch it.
    fs.renameSync(fixture.repo, `${fixture.repo}-offline`);
    const migrated = runCli(['list'], sb.env, { ...localOnlyGit, GIT_ALLOW_PROTOCOL: '' });
    assert.equal(migrated.status, 0, migrated.stderr);
    assert.ok(migrated.stdout.includes(fixture.dojo), migrated.stdout);
  } finally {
    stubGit();
  }
  assert.deepEqual(JSON.parse(fs.readFileSync(fixture.metadata, 'utf8')), {
    schema_version: 1, location: fixture.repo, origin: fixture.repo,
  });
  const listed = runCli(['list'], sb.env);
  assert.ok(listed.stdout.includes(fixture.dojo), listed.stdout);
  const run = runCli(['run', fixture.dojo, path.join(sb.dir, 'workspace')], sb.env);
  assert.equal(run.status, 0, run.stderr);
  assert.deepEqual(gitCalls(), [], 'migration must not repeat config checks on marked reads');
});

for (const origin of ['different', 'missing', 'multiple']) {
  test(`native cache identity: legacy ${origin} origin cannot be adopted or pulled`, { skip }, () => {
    const fixture = cloneFixture();
    fs.unlinkSync(fixture.metadata);
    stubLocalOrigin(origin === 'different' ? `${fixture.repo}-other`
      : origin === 'multiple' ? `${fixture.repo}\0${fixture.repo}-other` : '');
    assertUnavailable(fixture, /remote\.origin\.url/);
    const { root } = makeAssets();
    const update = runCli(['update'], sb.env, { BRK_HOME: root });
    assertFailed(update);
    assert.ok(gitCalls().every((args) => args[0] === 'config'));
    assert.equal(fs.existsSync(fixture.metadata), false, 'must not mark an unverified cache');
    assert.ok(fs.existsSync(path.join(fixture.cache, fixture.dojo)));
  });
}

for (const kind of ['malformed', 'unsupported', 'symlink', 'dangling symlink']) {
  test(`native cache identity: ${kind} metadata fails closed without overwriting it`, {
    skip: skip || (kind.includes('symlink') && process.platform === 'win32'),
  }, () => {
    const fixture = cloneFixture();
    const outside = path.join(sb.dir, 'outside-metadata');
    const original = fs.readFileSync(fixture.metadata, 'utf8');
    if (kind.includes('symlink')) {
      fs.unlinkSync(fixture.metadata);
      if (kind === 'symlink') fs.writeFileSync(outside, original);
      fs.symlinkSync(outside, fixture.metadata);
    } else {
      fs.writeFileSync(fixture.metadata, kind === 'malformed' ? '{ nope' : JSON.stringify({
        schema_version: 42, location: fixture.repo, origin: fixture.repo,
      }));
    }
    const before = kind.includes('symlink') ? fs.readlinkSync(fixture.metadata)
      : fs.readFileSync(fixture.metadata, 'utf8');
    assertUnavailable(fixture, kind.includes('symlink') ? /symlink/ : /source metadata/);
    const { root } = makeAssets();
    assertFailed(runCli(['update'], sb.env, { BRK_HOME: root }));
    assert.deepEqual(gitCalls(), []);
    assert.equal(kind.includes('symlink') ? fs.readlinkSync(fixture.metadata)
      : fs.readFileSync(fixture.metadata, 'utf8'), before);
    if (kind === 'symlink') assert.equal(fs.readFileSync(outside, 'utf8'), original);
    if (kind === 'dangling symlink') assert.equal(fs.existsSync(outside), false);
  });
}

for (const target of ['cache root', 'cache parent', '.git', '.git/config', 'dangling cache root']) {
  test(`native cache identity: rejects a symlink at ${target} without following or deleting it`, {
    skip: skip || process.platform === 'win32',
  }, () => {
    const fixture = cloneFixture();
    const link = target === 'cache parent' ? sb.cacheDir
      : target === '.git' ? path.join(fixture.cache, '.git')
        : target === '.git/config' ? path.join(fixture.cache, '.git', 'config') : fixture.cache;
    const outside = path.join(sb.dir, 'saved-cache-data');
    fs.renameSync(link, outside);
    const destination = target === 'dangling cache root' ? `${outside}-missing` : outside;
    fs.symlinkSync(destination, link, target === '.git/config' ? 'file' : 'dir');
    if (target === '.git/config') fs.unlinkSync(fixture.metadata); // local-only legacy validation
    assertUnavailable(fixture, /symlink/);
    const { root } = makeAssets();
    assertFailed(runCli(['update'], sb.env, { BRK_HOME: root }));
    assert.equal(fs.readlinkSync(link), destination);
    assert.ok(fs.existsSync(outside), 'original data must survive');
    assert.deepEqual(gitCalls(), []);
  });
}

test('native cache identity: sidecar-like aliases cannot collide with another cache metadata', { skip }, () => {
  const fixture = cloneFixture();
  const other = cloneFixture({ name: 'origin-b', dojo: 'dojo-b', alias: '.shared-source.json' });
  assert.equal(JSON.parse(fs.readFileSync(fixture.metadata, 'utf8')).location, fixture.repo);
  assert.equal(JSON.parse(fs.readFileSync(other.metadata, 'utf8')).location, other.repo);
  const listed = runCli(['list'], sb.env);
  assert.ok(listed.stdout.includes(fixture.dojo), listed.stdout);
  assert.ok(listed.stdout.includes(other.dojo), listed.stdout);
  assert.deepEqual(gitCalls(), []);
});

test('native BRK_HOME: a valid relocated registry supplies list and run assets', { skip }, () => {
  const { root, dojoDir } = makeAssets();
  const extraEnv = { BRK_HOME: root };
  const registries = runCli(['registry', 'list'], sb.env, extraEnv);
  assert.equal(registries.status, 0, registries.stderr);
  assert.match(registries.stdout, /relocated\s+\(bundled\)/);
  assert.ok(registries.stdout.includes(fs.realpathSync(root)), registries.stdout);
  assert.ok(!registries.stdout.includes(REPO_ROOT), 'must not use build-time assets');
  const list = runCli(['list'], sb.env, extraEnv);
  assert.equal(list.status, 0, list.stderr);
  assert.match(list.stdout, /relocated-dojo/);
  assert.doesNotMatch(list.stdout, /demonkey/);
  const run = runCli(['run', 'relocated-dojo', path.join(sb.dir, 'workspace')], sb.env, extraEnv);
  assert.equal(run.status, 0, run.stderr);
  const launches = sb.calls().filter((call) => call.argv[0] === '--plugin-dir');
  assert.equal(launches.length, 1);
  assert.equal(launches[0].argv[1], fs.realpathSync(dojoDir));
  assert.deepEqual(gitCalls(), []);
});

for (const invalid of ['missing directory', 'missing marketplace', 'malformed JSON', 'invalid schema']) {
  test(`native BRK_HOME: ${invalid} fails without falling back to bundled assets`, { skip }, () => {
    const root = path.join(sb.dir, 'invalid assets');
    if (invalid !== 'missing directory') fs.mkdirSync(root);
    if (invalid === 'malformed JSON' || invalid === 'invalid schema') {
      fs.mkdirSync(path.join(root, '.claude-plugin'));
      fs.writeFileSync(path.join(root, '.claude-plugin', 'marketplace.json'),
        invalid === 'malformed JSON' ? '{ not valid JSON' : JSON.stringify({ plugins: [] }));
    }
    for (const args of [['registry', 'list'], ['list'], ['run', 'demonkey', path.join(sb.dir, 'workspace')]]) {
      const r = runCli(args, sb.env, { BRK_HOME: root });
      assertFailed(r);
      assert.match(r.stderr, /BRK_HOME/);
      assert.doesNotMatch(r.stdout, /demonkey|c10k-dojo/);
    }
    assert.ok(!sb.calls().some((call) => call.argv[0] === '--plugin-dir'));
    assert.deepEqual(gitCalls(), []);
  });
}

for (const kind of ['absolute', 'parent traversal', 'symlink']) {
  test(`native run: a ${kind} source cannot launch a plugin outside its registry`, {
    skip: skip || (kind === 'symlink' && process.platform === 'win32'),
  }, () => {
    // A real, valid plugin exists outside the root: failure must be confinement,
    // not merely a missing source directory or manifest.
    const outside = path.join(sb.dir, 'outside-dojo');
    fs.mkdirSync(path.join(outside, '.claude-plugin'), { recursive: true });
    fs.writeFileSync(path.join(outside, '.claude-plugin', 'plugin.json'), JSON.stringify({
      name: 'relocated-dojo', version: '0.0.1', description: 'Outside the registry.',
    }));
    const source = kind === 'absolute' ? outside
      : kind === 'parent traversal' ? '../outside-dojo' : './linked-dojo';
    const { root } = makeAssets({ source });
    if (kind === 'symlink') fs.symlinkSync(outside, path.join(root, 'linked-dojo'), 'dir');
    const r = runCli(['run', 'relocated-dojo', path.join(sb.dir, 'workspace')], sb.env, { BRK_HOME: root });
    assertFailed(r);
    assert.deepEqual(sb.calls(), [], 'an escaping source must never launch the plugin');
    assert.deepEqual(gitCalls(), []);
  });
}

for (const signal of ['SIGINT', 'SIGTERM']) {
  test(`native run: a child terminated by ${signal} exits with 128 + signal`, {
    skip: skip || process.platform === 'win32',
  }, () => {
    const executable = writeStub('signalled plugin', sb.env.BRK_STUB_LOG, `
// Bound the test if the platform unexpectedly ignores the signal.
setTimeout(() => process.exit(99), 1000);
process.kill(process.pid, ${JSON.stringify(signal)});`);
    const r = runCli(['run', 'demonkey', path.join(sb.dir, 'workspace')], sb.env, {
      BRK_CLAUDE_BIN: executable,
    });
    assert.equal(r.status, 128 + os.constants.signals[signal], r.stderr);
    assert.equal(sb.calls().length, 1);
  });
}
