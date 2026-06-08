// `dojo install <name>` — persistent install via Claude Code's native plugin
// system, so the dojo's slash commands work in any later `claude` session.
import { resolveDojo } from '../registry.js';
import { claudePlugin } from '../lib/claude.js';

export function cmdInstall(argv) {
  const name = argv[0];
  if (!name) {
    console.error('usage: dojo install <name>');
    return 2;
  }
  const found = resolveDojo(name);
  if (!found) {
    console.error(`dojo: unknown dojo '${name}'. Run 'dojo list' to see what's available.`);
    return 1;
  }

  // Add the marketplace (idempotent — a re-add just no-ops/refreshes). For git
  // registries hand Claude the URL; for the local self repo, the path.
  const source = found.registry.kind === 'git' ? found.registry.location : found.registry.root;
  claudePlugin(['marketplace', 'add', source]);

  const inst = claudePlugin(['install', `${name}@${found.marketplaceName}`], { inherit: true });
  if ((inst.status ?? 0) === 0) {
    console.error(`dojo: installed ${name}@${found.marketplaceName}. Start it in any project with /${name}:start`);
  }
  return inst.status ?? 0;
}

export function cmdUninstall(argv) {
  const name = argv[0];
  if (!name) {
    console.error('usage: dojo uninstall <name>');
    return 2;
  }
  const found = resolveDojo(name);
  if (!found) {
    console.error(`dojo: unknown dojo '${name}'.`);
    return 1;
  }
  const r = claudePlugin(['uninstall', `${name}@${found.marketplaceName}`], { inherit: true });
  return r.status ?? 0;
}
