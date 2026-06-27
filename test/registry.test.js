import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { makeEnv, runCli } from './helpers/env.js';
import { makeFixtureRegistry } from './helpers/fixture-registry.js';

let sb;
beforeEach(() => { sb = makeEnv(); });
afterEach(() => sb.cleanup());

test('registry list shows the bundled self registry', () => {
  const r = runCli(['registry', 'list'], sb.env);
  assert.equal(r.status, 0);
  assert.match(r.stdout, /brk\s+\(bundled\)/);
});

test('registry add writes the config and list reflects it', () => {
  const { repo } = makeFixtureRegistry(sb.dir);
  const add = runCli(['registry', 'add', repo, 'fakereg'], sb.env);
  assert.equal(add.status, 0);

  const cfg = path.join(sb.configDir, 'registries');
  assert.ok(fs.existsSync(cfg));
  assert.match(fs.readFileSync(cfg, 'utf8'), /fakereg/);

  const list = runCli(['registry', 'list'], sb.env);
  assert.match(list.stdout, /fakereg/);
});

test('a dojo from an added registry resolves and is listable + runnable', () => {
  const { repo } = makeFixtureRegistry(sb.dir);
  runCli(['registry', 'add', repo, 'fakereg'], sb.env);

  const list = runCli(['list'], sb.env);
  assert.match(list.stdout, /mini-dojo/);
  assert.match(list.stdout, /A tiny fixture dojo/);

  const run = runCli(['run', 'mini-dojo'], sb.env);
  assert.equal(run.status, 0);
  // The log accumulates across both runCli calls; the launch is the --plugin-dir one.
  const launch = sb.calls().find((c) => c.argv[0] === '--plugin-dir');
  assert.ok(launch, 'expected a launch call');
  // Resolved into the cache clone, not the self repo.
  assert.match(launch.argv[1], /cache[/\\]brk[/\\]fakereg[/\\]mini-dojo$/);
});

test('registry remove drops the entry', () => {
  const { repo } = makeFixtureRegistry(sb.dir);
  runCli(['registry', 'add', repo, 'fakereg'], sb.env);
  const rm = runCli(['registry', 'remove', 'fakereg'], sb.env);
  assert.equal(rm.status, 0);
  const list = runCli(['registry', 'list'], sb.env);
  assert.doesNotMatch(list.stdout, /fakereg/);
});

test('adding the same registry twice is a no-op, not a duplicate', () => {
  const { repo } = makeFixtureRegistry(sb.dir);
  runCli(['registry', 'add', repo, 'fakereg'], sb.env);
  const again = runCli(['registry', 'add', repo, 'fakereg'], sb.env);
  assert.equal(again.status, 0);
  assert.match(again.stderr, /already added/);
  const lines = fs.readFileSync(path.join(sb.configDir, 'registries'), 'utf8')
    .split('\n').filter(Boolean);
  assert.equal(lines.length, 1, 'should not duplicate the registry line');
});
