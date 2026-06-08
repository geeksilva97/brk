// Thin wrappers over the `git` binary (the only way external registries are fetched).
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

export function git(args, opts = {}) {
  return spawnSync('git', args, { encoding: 'utf8', ...opts });
}

function isGitRepo(dir) {
  return fs.existsSync(path.join(dir, '.git'));
}

// Clone `url` into `dir`, or `git pull` if it's already a checkout. Returns
// { ok, error } — never throws, so a single bad registry can't crash a `list`.
export function cloneOrPull(url, dir) {
  try {
    if (isGitRepo(dir)) {
      const r = git(['-C', dir, 'pull', '--ff-only', '--quiet']);
      return { ok: r.status === 0, error: r.stderr };
    }
    fs.mkdirSync(path.dirname(dir), { recursive: true });
    const r = git(['clone', '--quiet', '--depth', '1', url, dir]);
    return { ok: r.status === 0, error: r.stderr };
  } catch (err) {
    return { ok: false, error: String(err) };
  }
}

// `git pull` an existing local checkout (the self registry, when it is one).
export function pullIfRepo(dir) {
  if (!isGitRepo(dir)) return { ok: true, skipped: true };
  const r = git(['-C', dir, 'pull', '--ff-only', '--quiet']);
  return { ok: r.status === 0, error: r.stderr };
}
