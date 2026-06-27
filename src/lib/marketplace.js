// Read + parse Claude Code marketplace/plugin manifests. Plain JSON.parse —
// no jq, no grep/sed (the old bash dojo.sh dance is gone here).
import fs from 'node:fs';
import path from 'node:path';

export function readMarketplace(registryRoot) {
  const file = path.join(registryRoot, '.claude-plugin', 'marketplace.json');
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

export function readPluginManifest(pluginDir) {
  const file = path.join(pluginDir, '.claude-plugin', 'plugin.json');
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

// Resolve a marketplace plugin entry's on-disk directory. Supports the string
// form (`"./subdir"`, relative to the registry root) we use for local registries.
export function pluginDir(registryRoot, entry) {
  const src = entry.source;
  if (typeof src === 'string') return path.resolve(registryRoot, src);
  // Object sources (github/git-subdir/etc.) are resolved by Claude Code itself
  // on `install`; we can't point `--plugin-dir` at them for ephemeral `run`.
  return null;
}

// A short, human description for `brk list`: prefer the plugin's own manifest,
// fall back to the marketplace entry.
export function describe(registryRoot, entry) {
  try {
    const dir = pluginDir(registryRoot, entry);
    if (dir) return readPluginManifest(dir).description || entry.description || '';
  } catch { /* fall through */ }
  return entry.description || '';
}
