// `brk run [--watch] <name> [project-dir] [claude args...]` — start a dojo
// immediately, nothing installed. Generalizes demonkey.sh to any registered dojo.
import fs from 'node:fs';
import path from 'node:path';
import { resolveDojo } from '../registry.js';
import { launchDojo } from '../lib/claude.js';
import { WATCH_LOOP_PROMPT } from '../lib/watch.js';

export function cmdRun(argv) {
  // --watch/-w is a brk flag (never forwarded to claude): it seeds an
  // auto-review `/loop` so the tutor reviews the learner's code on each save.
  const watch = argv.includes('--watch') || argv.includes('-w');
  const positional = argv.filter((a) => a !== '--watch' && a !== '-w');

  const name = positional[0];
  if (!name) {
    console.error('usage: brk run [--watch] <name> [project-dir] [claude args...]');
    return 2;
  }
  const rest = positional.slice(1);
  let projectDir;
  let extra = rest;
  // A leading non-flag arg is the project dir; the remainder passes to claude.
  if (rest[0] && !rest[0].startsWith('-')) {
    projectDir = rest[0];
    extra = rest.slice(1);
  }
  // The seeded prompt rides at the end of the claude args, before launchDojo
  // appends the variadic --disallowed-tools, so it parses as the first message.
  if (watch) extra = [...extra, WATCH_LOOP_PROMPT];

  const found = resolveDojo(name);
  if (!found) {
    console.error(`brk: unknown dojo '${name}'. Run 'brk list' to see what's available.`);
    return 1;
  }
  if (!found.dir || !fs.existsSync(found.dir)) {
    console.error(`brk: '${name}' resolves to a source this CLI can't run ephemerally; try 'brk install ${name}'.`);
    return 1;
  }

  let cwd = process.cwd();
  if (projectDir) {
    fs.mkdirSync(projectDir, { recursive: true });
    cwd = path.resolve(projectDir);
  }
  return launchDojo(found.dir, { cwd, extraArgs: extra, jail: true });
}
