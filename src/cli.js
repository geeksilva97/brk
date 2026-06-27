// Command dispatch. Returns a process exit code; never calls process.exit so it
// stays unit-testable by importing this function directly.
import { cmdRun } from './commands/run.js';
import { cmdInstall, cmdUninstall } from './commands/install.js';
import { cmdList } from './commands/list.js';
import { cmdUpdate } from './commands/update.js';
import { cmdRegistry } from './commands/registry.js';
import { cmdNew } from './commands/new.js';
import { cmdHelp } from './commands/help.js';

export function main(argv) {
  const [command, ...rest] = argv;
  switch (command) {
    case 'run': return cmdRun(rest);
    case 'install': return cmdInstall(rest);
    case 'uninstall': return cmdUninstall(rest);
    case 'list': case 'ls': return cmdList(rest);
    case 'update': return cmdUpdate(rest);
    case 'registry': return cmdRegistry(rest);
    case 'new': return cmdNew(rest);
    case 'help': case '--help': case '-h': case undefined: return cmdHelp();
    default:
      console.error(`brk: unknown command '${command}'. Run 'brk help'.`);
      return 2;
  }
}
