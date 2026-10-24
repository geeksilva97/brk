// Exercise the source installer in a disposable checkout, never the user's tree.
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { REPO_ROOT } from './helpers/env.js';

const native = process.env.BRK_TEST_BIN;
const skip = process.platform === 'win32' || !native;

test('legacy package.json declares no runtime dependencies', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'package.json'), 'utf8'));
  assert.equal(pkg.private, true);
  assert.ok(!pkg.dependencies || Object.keys(pkg.dependencies).length === 0);
  assert.ok(!pkg.devDependencies || Object.keys(pkg.devDependencies).length === 0);
});

let home;
let checkout;
let binDir;
let env;
beforeEach(() => {
  home = fs.mkdtempSync(path.join(os.tmpdir(), 'brk-install-'));
  checkout = path.join(home, 'checkout with spaces');
  binDir = path.join(home, 'bin');
  const tools = path.join(home, 'tools');
  fs.mkdirSync(path.join(checkout, 'bin'), { recursive: true });
  fs.mkdirSync(path.join(checkout, '.claude-plugin'));
  fs.mkdirSync(tools);
  fs.copyFileSync(path.join(REPO_ROOT, 'install.sh'), path.join(checkout, 'install.sh'));
  fs.writeFileSync(path.join(checkout, '.claude-plugin', 'marketplace.json'), JSON.stringify({ name: 'brk', plugins: [] }));
  fs.writeFileSync(path.join(tools, 'cargo'), `#!/bin/sh
printf '%s\\n' "$@" > "$BRK_INSTALL_LOG"
[ -z "$BRK_INSTALL_FAIL" ] || exit 1
mkdir -p "$BRK_INSTALL_CHECKOUT/target/release"
cp "$BRK_INSTALL_SOURCE" "$BRK_INSTALL_CHECKOUT/target/release/brk"
`, { mode: 0o755 });
  env = {
    ...process.env,
    HOME: home,
    PATH: `${tools}${path.delimiter}${process.env.PATH}`,
    BRK_BIN_DIR: binDir,
    BRK_SKIP_PULL: '1',
    BRK_INSTALL_CHECKOUT: checkout,
    BRK_INSTALL_SOURCE: native || '',
    BRK_INSTALL_LOG: path.join(home, 'cargo.log'),
    BRK_INSTALL_FAIL: '',
  };
  delete env.BRK_HOME;
  delete env.BRK_RUNTIME_BIN;
});
afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

function install(extraEnv = {}) {
  return spawnSync('bash', [path.join(checkout, 'install.sh')], {
    encoding: 'utf8', env: { ...env, ...extraEnv },
  });
}

test('install.sh builds, atomically installs, and links a relocated native CLI', { skip }, () => {
  const r = install();
  assert.equal(r.status, 0, r.stderr);
  const link = path.join(binDir, 'brk');
  assert.equal(fs.realpathSync(link), fs.realpathSync(path.join(checkout, 'bin', 'brk')));
  const cargoArgs = fs.readFileSync(env.BRK_INSTALL_LOG, 'utf8').trim().split('\n');
  assert.deepEqual(cargoArgs, ['build', '--locked', '--release', '--manifest-path', path.join(checkout, 'Cargo.toml'), '--target-dir', path.join(checkout, 'target')]);
  const help = spawnSync(link, ['help'], { encoding: 'utf8', env, cwd: home });
  assert.equal(help.status, 0, help.stderr);
  assert.match(help.stdout, /USAGE/);
  const registry = spawnSync(link, ['registry', 'list'], { encoding: 'utf8', env, cwd: home });
  assert.equal(registry.status, 0, registry.stderr);
  assert.ok(registry.stdout.includes(checkout), registry.stdout);
  assert.ok(!registry.stdout.includes(REPO_ROOT), 'must not use the build-time checkout');
});

test('failed build preserves the installed executable and link', { skip }, () => {
  assert.equal(install().status, 0);
  const installed = path.join(checkout, 'bin', 'brk');
  const before = fs.readFileSync(installed);
  const r = install({ BRK_INSTALL_FAIL: '1' });
  assert.notEqual(r.status, 0);
  assert.deepEqual(fs.readFileSync(installed), before);
  assert.equal(fs.realpathSync(path.join(binDir, 'brk')), installed);
  assert.deepEqual(fs.readdirSync(path.join(checkout, 'bin')), ['brk']);
});
