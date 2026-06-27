#!/usr/bin/env node
// Fake `claude` binary used by the test suite. It records every invocation
// (argv + relevant env + cwd) as a JSON line to $BRK_STUB_LOG, prints canned
// output, and exits — so tests assert the exact command the CLI builds WITHOUT
// launching a real Claude session. Plain CommonJS (runs as an extensionless file).
const fs = require('fs');

const argv = process.argv.slice(2);
const log = process.env.BRK_STUB_LOG;
if (log) {
  const rec = {
    argv,
    cwd: process.cwd(),
    promptSuggest: process.env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION ?? null,
  };
  fs.appendFileSync(log, JSON.stringify(rec) + '\n');
}

// `claude plugin list` — emit any ids the test seeded so the [installed] marker
// can be exercised (comma-separated "name@marketplace" in BRK_STUB_INSTALLED).
if (argv[0] === 'plugin' && argv[1] === 'list') {
  const seed = process.env.BRK_STUB_INSTALLED || '';
  if (seed) process.stdout.write(seed.split(',').join('\n') + '\n');
}

process.exit(Number(process.env.BRK_STUB_EXIT || 0));
