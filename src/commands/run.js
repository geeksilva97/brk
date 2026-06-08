// `dojo run <name> [project-dir] [claude args...]` — start a dojo immediately,
// nothing installed. Generalizes demonkey.sh to any registered dojo.
import fs from 'node:fs';
import path from 'node:path';
import { resolveDojo } from '../registry.js';
import { launchDojo } from '../lib/claude.js';

export function cmdRun(argv) {
  const name = argv[0];
  if (!name) {
    console.error('usage: dojo run <name> [project-dir] [claude args...]');
    return 2;
  }
  const rest = argv.slice(1);
  let projectDir;
  let extra = rest;
  // A leading non-flag arg is the project dir; the remainder passes to claude.
  if (rest[0] && !rest[0].startsWith('-')) {
    projectDir = rest[0];
    extra = rest.slice(1);
  }

  const found = resolveDojo(name);
  if (!found) {
    console.error(`dojo: unknown dojo '${name}'. Run 'dojo list' to see what's available.`);
    return 1;
  }
  if (!found.dir || !fs.existsSync(found.dir)) {
    console.error(`dojo: '${name}' resolves to a source this CLI can't run ephemerally; try 'dojo install ${name}'.`);
    return 1;
  }

  let cwd = process.cwd();
  if (projectDir) {
    fs.mkdirSync(projectDir, { recursive: true });
    cwd = path.resolve(projectDir);
  }
  return launchDojo(found.dir, { cwd, extraArgs: extra, jail: true });
}
