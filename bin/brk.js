#!/usr/bin/env node
// Thin entry point — this is the file install.sh symlinks onto PATH as `brk`.
import { main } from '../src/cli.js';

process.exit(main(process.argv.slice(2)));
