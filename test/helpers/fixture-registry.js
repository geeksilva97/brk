// Build a throwaway git repo shaped like a dojos registry (marketplace.json +
// one tiny dojo), so registry-agnostic resolution is tested against something
// other than the real repo. Returns the repo path (a valid `git clone` source).
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

export function makeFixtureRegistry(parentDir, { name = 'fakereg', dojo = 'mini-dojo' } = {}) {
  const repo = path.join(parentDir, name);
  const dojoDir = path.join(repo, dojo);
  fs.mkdirSync(path.join(repo, '.claude-plugin'), { recursive: true });
  fs.mkdirSync(path.join(dojoDir, '.claude-plugin'), { recursive: true });

  fs.writeFileSync(
    path.join(repo, '.claude-plugin', 'marketplace.json'),
    JSON.stringify({
      name,
      owner: { name: 'Test' },
      plugins: [{ name: dojo, source: `./${dojo}` }],
    }, null, 2),
  );
  fs.writeFileSync(
    path.join(dojoDir, '.claude-plugin', 'plugin.json'),
    JSON.stringify({ name: dojo, description: 'A tiny fixture dojo.', version: '0.0.1' }, null, 2),
  );

  const git = (args) => spawnSync('git', args, { cwd: repo, encoding: 'utf8' });
  git(['init', '-q', '-b', 'main']);
  git(['config', 'user.email', 'test@example.com']);
  git(['config', 'user.name', 'Test']);
  git(['add', '-A']);
  git(['commit', '-q', '-m', 'fixture registry']);
  return { repo, name, dojo };
}
