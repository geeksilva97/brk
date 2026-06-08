// Everything that shells out to the `claude` CLI. `DOJO_CLAUDE_BIN` lets tests
// point at a stub; otherwise `claude` is resolved from PATH.
import { spawnSync } from 'node:child_process';

const CLAUDE = process.env.DOJO_CLAUDE_BIN || 'claude';

// Launch a dojo session in `cwd` with the plugin loaded. The learner-dojo flags
// (offline jail + no prompt suggestions) are uniform — ported from demonkey.sh.
// `jail: false` is for dojo-forge (authoring, not a learner session).
export function launchDojo(pluginDir, { cwd, extraArgs = [], jail = true } = {}) {
  const args = ['--plugin-dir', pluginDir, ...extraArgs];
  if (jail) args.push('--disallowed-tools', 'WebSearch', 'WebFetch');
  const env = { ...process.env };
  if (jail) env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION = 'false';
  const res = spawnSync(CLAUDE, args, { stdio: 'inherit', cwd, env });
  if (res.error) {
    console.error(`dojo: could not launch '${CLAUDE}': ${res.error.message}`);
    return 127;
  }
  return res.status ?? 1;
}

// Run `claude plugin <args...>` and capture output. Returns the spawnSync result.
export function claudePlugin(args, { inherit = false } = {}) {
  return spawnSync(CLAUDE, ['plugin', ...args], {
    encoding: 'utf8',
    stdio: inherit ? 'inherit' : 'pipe',
  });
}

// Best-effort set of installed "name@marketplace" ids, parsed from `claude plugin list`.
// Tolerant of format drift: returns an empty set if anything goes sideways.
export function installedIds() {
  try {
    const r = claudePlugin(['list']);
    if (r.status !== 0 || !r.stdout) return new Set();
    const ids = new Set();
    for (const m of r.stdout.matchAll(/([a-z0-9][\w-]*)@([a-z0-9][\w-]*)/gi)) {
      ids.add(`${m[1]}@${m[2]}`);
    }
    return ids;
  } catch {
    return new Set();
  }
}
