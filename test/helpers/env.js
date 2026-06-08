// Test harness: a fully isolated environment per test (temp HOME/XDG dirs, a
// fake `claude` on PATH) plus helpers to run the CLI and read what the stub saw.
import os from 'node:os';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(HERE, '..', '..');
export const CLI = path.join(REPO_ROOT, 'bin', 'dojo.js');
const STUB_SRC = path.join(HERE, 'claude-stub.cjs');

// Build an isolated sandbox. Returns { dir, env, cleanup, calls, configDir }.
export function makeEnv() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'dojo-test-'));
  const home = path.join(dir, 'home');
  const configHome = path.join(dir, 'config');
  const cacheHome = path.join(dir, 'cache');
  const bin = path.join(dir, 'bin');
  for (const d of [home, configHome, cacheHome, bin]) fs.mkdirSync(d, { recursive: true });

  const claudePath = path.join(bin, 'claude');
  fs.copyFileSync(STUB_SRC, claudePath);
  fs.chmodSync(claudePath, 0o755);

  const log = path.join(dir, 'claude.log');
  const env = {
    ...process.env,
    HOME: home,
    XDG_CONFIG_HOME: configHome,
    XDG_CACHE_HOME: cacheHome,
    PATH: `${bin}${path.delimiter}${process.env.PATH}`,
    DOJO_STUB_LOG: log,
  };
  // Don't leak the parent's overrides into the child.
  delete env.DOJO_CLAUDE_BIN;
  delete env.DOJO_STUB_INSTALLED;
  delete env.DOJO_STUB_EXIT;

  return {
    dir,
    env,
    configDir: path.join(configHome, 'dojo'),
    cacheDir: path.join(cacheHome, 'dojo'),
    calls() {
      if (!fs.existsSync(log)) return [];
      return fs.readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l));
    },
    cleanup() {
      fs.rmSync(dir, { recursive: true, force: true });
    },
  };
}

// Run the CLI as a child process with the sandbox env. Extra env merges last.
export function runCli(args, env, extraEnv = {}) {
  const r = spawnSync(process.execPath, [CLI, ...args], {
    encoding: 'utf8',
    env: { ...env, ...extraEnv },
  });
  return { status: r.status, stdout: r.stdout || '', stderr: r.stderr || '' };
}
