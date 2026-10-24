# Contributing

## Adding a dojo

A dojo is just a Claude Code plugin directory. To make it appear in `brk list` / `brk run`:

1. Drop the plugin in `dojos/` (e.g. `dojos/my-dojo/`) with a valid
   `.claude-plugin/plugin.json`.
2. Add one line to `.claude-plugin/marketplace.json`:

   ```json
   { "name": "my-dojo", "source": "./dojos/my-dojo", "category": "workshop" }
   ```

   The `name` must match the plugin's own manifest `name` (a test enforces this).
3. `node --test` — the manifest-invariant tests check the entry resolves, the names match,
   and the plugin doesn't illegally declare a `hooks` field.

Don't hand-write a dojo from scratch — use the generator: `brk new "<your topic>"` runs
**dojo-forge**, which interviews you and scaffolds a complete, validating dojo in the right
shape (tutor skill, jail hooks, per-project state, curriculum). Then move it into `dojos/`
per the steps above.

See the README's **Creating a new dojo** section for full details on both forge-generated
and manual dojos.

## Running the tests

The native runtime needs Rust/Cargo ≥ 1.89. The compatibility suite needs Node ≥ 18
and no npm dependencies:

```bash
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked
cargo build --locked
BRK_TEST_BIN="$PWD/target/debug/brk" node --test test/*.test.js
node --test test/*.test.js              # legacy CLI and standalone shell fallback
node --test --experimental-test-coverage test/*.test.js
```

Native-only tests skip when `BRK_TEST_BIN` is unset. Installer tests run a stubbed build
inside a disposable checkout; they never pull, rebuild, or chmod the working checkout.
CI exercises both paths on Linux and macOS.

The suite never launches a real Claude session: a fake `claude` on `PATH`
(`test/helpers/claude-stub.cjs`) records the exact command the CLI builds, and every test
runs in an isolated temp `HOME`/XDG sandbox (`test/helpers/env.js`). The bash hook/state tests
(`guards`, `dojo-state`) are skipped on Windows.

The suite has no live-client tier. Real interactive sessions and Docker benchmark runs
must be checked separately; the automated tests do not claim to cover them.

## Code shape

The native CLI is one Cargo package: `rust/main.rs` dispatches to `rust/cli.rs`,
`rust/state.rs` or `rust/hooks.rs`; registries, paths, manifests and subprocesses have
separate modules.
Keep dependencies small and justified. JSON uses serde rather than handwritten parsing;
`tempfile` supports atomic progress writes. Commit Cargo.lock.

The legacy CLI remains plain ESM JavaScript with Node builtins only, without transpilation,
bundling or npm dependencies. `bin/brk.js` → `src/cli.js` dispatches to `src/commands/*`;
shared bits live in `src/lib/` (`claude.js`, `git.js`, `marketplace.js`). Keep this reference
path dependency-free while the compatibility tests exercise both implementations.

Do not replace curricula or reference implementations with Rust as part of runtime work.
See [RUST-MIGRATION.md](docs/RUST-MIGRATION.md) for deliberate compatibility changes and
remaining work.