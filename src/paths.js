// Filesystem locations the CLI uses. Honors XDG_* so tests can fully isolate.
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SRC_DIR = path.dirname(fileURLToPath(import.meta.url));

// The repo this CLI lives in IS the default ("self") registry — the bundled
// dojos are already on disk next to us, so no clone/network is needed for them.
export const REPO_ROOT = path.resolve(SRC_DIR, '..');

const configHome = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
const cacheHome = process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache');

export const CONFIG_DIR = path.join(configHome, 'dojo');
// One `git-url [name]` per line; blank lines and `#` comments ignored.
export const REGISTRIES_FILE = path.join(CONFIG_DIR, 'registries');
// External (git) registries are cloned here, one dir per registry name.
export const CACHE_DIR = path.join(cacheHome, 'dojo');
