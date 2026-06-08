import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { REPO_ROOT } from './helpers/env.js';

const marketplace = JSON.parse(
  fs.readFileSync(path.join(REPO_ROOT, '.claude-plugin', 'marketplace.json'), 'utf8'),
);

test('marketplace.json is well-formed', () => {
  assert.equal(typeof marketplace.name, 'string');
  assert.ok(Array.isArray(marketplace.plugins) && marketplace.plugins.length > 0);
});

test('every plugin entry resolves to a real plugin dir whose manifest name matches', () => {
  for (const entry of marketplace.plugins) {
    assert.equal(typeof entry.source, 'string', `${entry.name}: source must be a path string`);
    const dir = path.resolve(REPO_ROOT, entry.source);
    const manifest = path.join(dir, '.claude-plugin', 'plugin.json');
    assert.ok(fs.existsSync(manifest), `${entry.name}: missing ${manifest}`);
    const m = JSON.parse(fs.readFileSync(manifest, 'utf8'));
    assert.equal(m.name, entry.name, `${entry.name}: plugin.json name mismatch (${m.name})`);
  }
});

test('no dojo plugin.json carries a "hooks" field (it must auto-load from hooks/hooks.json)', () => {
  for (const entry of marketplace.plugins) {
    const dir = path.resolve(REPO_ROOT, entry.source);
    const m = JSON.parse(fs.readFileSync(path.join(dir, '.claude-plugin', 'plugin.json'), 'utf8'));
    assert.equal('hooks' in m, false, `${entry.name}: plugin.json must not declare "hooks"`);
  }
});
