// `brk registry add|list|remove` — manage extra registries. This is the
// scale surface: any org hosts a `dojos`-shaped repo, you add it here.
import fs from 'node:fs';
import path from 'node:path';
import { CONFIG_DIR, REGISTRIES_FILE } from '../paths.js';
import { listRegistries } from '../registry.js';

function readLines() {
  if (!fs.existsSync(REGISTRIES_FILE)) return [];
  return fs.readFileSync(REGISTRIES_FILE, 'utf8').split('\n').map((l) => l.trim()).filter(Boolean);
}

function writeLines(lines) {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  fs.writeFileSync(REGISTRIES_FILE, lines.join('\n') + (lines.length ? '\n' : ''));
}

export function cmdRegistry(argv) {
  const sub = argv[0];
  switch (sub) {
    case 'add': {
      const url = argv[1];
      const name = argv[2];
      if (!url) { console.error('usage: brk registry add <git-url> [name]'); return 2; }
      const lines = readLines().filter((l) => !l.startsWith('#'));
      const exists = lines.some((l) => l.split(/\s+/)[0] === url);
      if (exists) { console.error(`brk: registry '${url}' is already added.`); return 0; }
      lines.push(name ? `${url} ${name}` : url);
      writeLines(lines);
      console.error(`brk: added registry ${url}${name ? ` (${name})` : ''}.`);
      return 0;
    }
    case 'remove':
    case 'rm': {
      const target = argv[1];
      if (!target) { console.error('usage: brk registry remove <git-url|name>'); return 2; }
      const before = readLines();
      const after = before.filter((l) => {
        const [url, name] = l.split(/\s+/);
        return url !== target && name !== target;
      });
      if (after.length === before.length) { console.error(`brk: no registry matching '${target}'.`); return 1; }
      writeLines(after);
      console.error(`brk: removed '${target}'.`);
      return 0;
    }
    case 'list':
    case undefined: {
      for (const reg of listRegistries()) {
        const loc = reg.kind === 'local' ? reg.root : reg.location;
        console.log(`${reg.name.padEnd(20)} ${reg.kind === 'local' ? '(bundled)' : ''} ${loc}`);
      }
      console.log(`\nconfig: ${REGISTRIES_FILE}`);
      return 0;
    }
    default:
      console.error(`brk: unknown 'registry' subcommand '${sub}'. Use add | list | remove.`);
      return 2;
  }
}
