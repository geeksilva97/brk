// install.sh links the CLI onto PATH; the package carries no runtime deps.
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { REPO_ROOT } from './helpers/env.js';

const skip = process.platform === 'win32';

test('package.json declares no runtime dependencies (simplicity invariant)', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'package.json'), 'utf8'));
  assert.equal(pkg.private, true);
  assert.ok(!pkg.dependencies || Object.keys(pkg.dependencies).length === 0);
  assert.ok(!pkg.devDependencies || Object.keys(pkg.devDependencies).length === 0);
});

let home;
let binDir;
beforeEach(() => {
  home = fs.mkdtempSync(path.join(os.tmpdir(), 'brk-install-'));
  binDir = path.join(home, 'bin');
});
afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

test('install.sh symlinks brk and the linked CLI runs', { skip }, () => {
  const r = spawnSync('bash', [path.join(REPO_ROOT, 'install.sh')], {
    encoding: 'utf8',
    env: { ...process.env, HOME: home, BRK_BIN_DIR: binDir, BRK_SKIP_PULL: '1' },
  });
  assert.equal(r.status, 0, r.stderr);

  const link = path.join(binDir, 'brk');
  assert.ok(fs.existsSync(link), 'symlink should exist');
  assert.equal(fs.realpathSync(link), fs.realpathSync(path.join(REPO_ROOT, 'bin', 'brk.js')));

  const help = spawnSync(link, ['help'], { encoding: 'utf8' });
  assert.equal(help.status, 0);
  assert.match(help.stdout, /USAGE/);
});
