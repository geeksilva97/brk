// Registry model: the "self" registry is this repo (bundled dojos, no network);
// additional git registries come from the config file and are cloned to cache.
// This is the multi-tenant hook — other orgs host their own `dojos`-shaped repo.
import fs from 'node:fs';
import path from 'node:path';
import { REPO_ROOT, REGISTRIES_FILE, CACHE_DIR } from './paths.js';
import { readMarketplace, pluginDir } from './lib/marketplace.js';
import { cloneOrPull } from './lib/git.js';

function deriveName(url) {
  return path.basename(url).replace(/\.git$/, '') || 'registry';
}

// All known registries. The self repo is always first (local, no clone).
export function listRegistries() {
  const regs = [{ name: marketplaceName(REPO_ROOT) || 'brk', kind: 'local', location: REPO_ROOT, root: REPO_ROOT }];
  if (fs.existsSync(REGISTRIES_FILE)) {
    for (const line of fs.readFileSync(REGISTRIES_FILE, 'utf8').split('\n')) {
      const t = line.trim();
      if (!t || t.startsWith('#')) continue;
      const [url, name] = t.split(/\s+/);
      const regName = name || deriveName(url);
      regs.push({ name: regName, kind: 'git', location: url, root: path.join(CACHE_DIR, regName) });
    }
  }
  return regs;
}

function marketplaceName(root) {
  try { return readMarketplace(root).name; } catch { return null; }
}

// Ensure a registry's marketplace is on disk; clone/pull git ones. Returns the
// local root, or null if a git registry couldn't be fetched.
export function ensureRoot(reg) {
  if (reg.kind === 'local') return reg.root;
  const res = cloneOrPull(reg.location, reg.root);
  return res.ok ? reg.root : null;
}

// Read a registry's plugin entries (after ensuring it's on disk). Never throws.
export function registryPlugins(reg) {
  const root = ensureRoot(reg);
  if (!root) return { reg, root: null, plugins: [], error: 'unavailable' };
  try {
    const mkt = readMarketplace(root);
    return { reg, root, marketplaceName: mkt.name, plugins: mkt.plugins || [] };
  } catch (err) {
    return { reg, root, plugins: [], error: String(err) };
  }
}

// Find a dojo by name across registries. Locals are checked first so bundled
// dojos resolve with zero network. Returns the match or null.
export function resolveDojo(name) {
  const ordered = listRegistries().sort((a, b) => (a.kind === b.kind ? 0 : a.kind === 'local' ? -1 : 1));
  for (const reg of ordered) {
    const { root, marketplaceName: mktName, plugins } = registryPlugins(reg);
    if (!root) continue;
    const entry = plugins.find((p) => p.name === name);
    if (!entry) continue;
    const dir = pluginDir(root, entry);
    return { registry: reg, entry, dir, marketplaceName: mktName };
  }
  return null;
}
