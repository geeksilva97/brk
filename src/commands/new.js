// `brk new [topic]` — author a new dojo with the dojo-forge generator. This is
// NOT a learner session, so no offline jail (the generator may need the network).
import fs from 'node:fs';
import { resolveDojo } from '../registry.js';
import { launchDojo } from '../lib/claude.js';

export function cmdNew(argv) {
  const found = resolveDojo('dojo-forge');
  if (!found || !found.dir || !fs.existsSync(found.dir)) {
    console.error("brk: the 'dojo-forge' generator isn't available in any registry.");
    return 1;
  }
  const topic = argv.join(' ').trim();
  // Seed the generator's entry command if a topic was given.
  const extraArgs = topic ? [`/dojo-forge:new ${topic}`] : [];
  return launchDojo(found.dir, { cwd: process.cwd(), extraArgs, jail: false });
}
