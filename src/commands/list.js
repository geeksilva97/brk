// `brk list` — every dojo across every registry, with an [installed] marker.
import { listRegistries, registryPlugins } from '../registry.js';
import { describe } from '../lib/marketplace.js';
import { installedIds } from '../lib/claude.js';

export function cmdList() {
  const installed = installedIds();
  let any = false;

  for (const reg of listRegistries()) {
    const { root, marketplaceName: mktName, plugins, error } = registryPlugins(reg);
    if (!root || error) {
      console.log(`\n${reg.name}  (unavailable: ${error || 'could not fetch'})`);
      continue;
    }
    console.log(`\n${reg.name}${reg.kind === 'git' ? `  (${reg.location})` : ''}`);
    for (const entry of plugins) {
      any = true;
      const mark = installed.has(`${entry.name}@${mktName}`) ? ' [installed]' : '';
      const desc = trim(describe(root, entry), 92);
      console.log(`  ${entry.name.padEnd(16)}${mark ? mark.padEnd(13) : ''.padEnd(13)}${desc}`);
    }
  }

  if (!any) console.log('No dojos found.');
  else console.log("\nStart one with 'brk run <name>' or install with 'brk install <name>'.");
  return 0;
}

function trim(s, n) {
  s = (s || '').replace(/\s+/g, ' ').trim();
  return s.length > n ? `${s.slice(0, n - 1)}…` : s;
}
