import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import fs from 'node:fs';
import { makeEnv, runCli, REPO_ROOT } from './helpers/env.js';

let sb;
beforeEach(() => { sb = makeEnv(); });
afterEach(() => sb.cleanup());

test('help prints usage and exits 0', () => {
  const r = runCli(['help'], sb.env);
  assert.equal(r.status, 0);
  assert.match(r.stdout, /USAGE/);
  assert.match(r.stdout, /run <name>/);
});

test('no command prints help', () => {
  const r = runCli([], sb.env);
  assert.equal(r.status, 0);
  assert.match(r.stdout, /USAGE/);
});

test('unknown command exits 2', () => {
  const r = runCli(['frobnicate'], sb.env);
  assert.equal(r.status, 2);
  assert.match(r.stderr, /unknown command/);
});

test('list shows all four bundled dojos', () => {
  const r = runCli(['list'], sb.env);
  assert.equal(r.status, 0);
  for (const name of ['demonkey', 'c10k-dojo', 'reactor-dojo', 'dojo-forge']) {
    assert.match(r.stdout, new RegExp(name));
  }
});

test('list marks installed dojos from `claude plugin list`', () => {
  const r = runCli(['list'], sb.env, { DOJO_STUB_INSTALLED: 'demonkey@dojos' });
  assert.match(r.stdout, /demonkey\s+\[installed\]/);
});

test('run builds the exact claude invocation with jail flags', () => {
  const proj = path.join(sb.dir, 'ws');
  const r = runCli(['run', 'demonkey', proj, '--model', 'qwen'], sb.env);
  assert.equal(r.status, 0);
  const calls = sb.calls();
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].argv, [
    '--plugin-dir', path.join(REPO_ROOT, 'demonkey'),
    '--model', 'qwen',
    '--disallowed-tools', 'WebSearch', 'WebFetch',
  ]);
  assert.equal(calls[0].promptSuggest, 'false');
  assert.equal(calls[0].cwd, fs.realpathSync(proj));
});

test('run without a project dir uses cwd and still jails', () => {
  const r = runCli(['run', 'c10k-dojo'], sb.env);
  assert.equal(r.status, 0);
  const { argv } = sb.calls()[0];
  assert.deepEqual(argv, [
    '--plugin-dir', path.join(REPO_ROOT, 'c10k-dojo'),
    '--disallowed-tools', 'WebSearch', 'WebFetch',
  ]);
});

test('run unknown dojo exits 1 with a helpful message', () => {
  const r = runCli(['run', 'nope'], sb.env);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /unknown dojo 'nope'/);
});

test('run with no name exits 2', () => {
  const r = runCli(['run'], sb.env);
  assert.equal(r.status, 2);
});

test('install adds the marketplace then installs name@dojos', () => {
  const r = runCli(['install', 'demonkey'], sb.env);
  assert.equal(r.status, 0);
  const argvs = sb.calls().map((c) => c.argv);
  assert.deepEqual(argvs[0], ['plugin', 'marketplace', 'add', REPO_ROOT]);
  assert.deepEqual(argvs[1], ['plugin', 'install', 'demonkey@dojos']);
});

test('uninstall removes name@dojos', () => {
  const r = runCli(['uninstall', 'demonkey'], sb.env);
  assert.equal(r.status, 0);
  assert.deepEqual(sb.calls()[0].argv, ['plugin', 'uninstall', 'demonkey@dojos']);
});

test('new launches dojo-forge WITHOUT the jail', () => {
  const r = runCli(['new', 'a websocket server'], sb.env);
  assert.equal(r.status, 0);
  const call = sb.calls()[0];
  assert.deepEqual(call.argv, [
    '--plugin-dir', path.join(REPO_ROOT, 'dojo-forge'),
    '/dojo-forge:new a websocket server',
  ]);
  assert.equal(call.promptSuggest, null, 'no prompt-suggestion override for the generator');
});
