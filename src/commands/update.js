// `dojo update` — refresh the tool + every registry's dojos. The self repo is
// pulled in place; git registries are pulled in cache; then Claude's catalog.
import { listRegistries } from '../registry.js';
import { pullIfRepo, cloneOrPull } from '../lib/git.js';
import { claudePlugin } from '../lib/claude.js';

export function cmdUpdate() {
  for (const reg of listRegistries()) {
    if (reg.kind === 'local') {
      const r = pullIfRepo(reg.root);
      console.log(`${reg.name}: ${r.skipped ? 'not a git checkout (skipped)' : r.ok ? 'updated' : `pull failed — ${oneline(r.error)}`}`);
    } else {
      const r = cloneOrPull(reg.location, reg.root);
      console.log(`${reg.name}: ${r.ok ? 'updated' : `fetch failed — ${oneline(r.error)}`}`);
    }
  }
  // Refresh Claude's view of any installed marketplaces (best effort).
  claudePlugin(['marketplace', 'update']);
  return 0;
}

function oneline(s) {
  return (s || 'unknown error').split('\n')[0].trim();
}
