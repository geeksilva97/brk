# Rust runtime migration — first increment

## Scope

The native CLI and shared progress runtime live in one Cargo package. The JavaScript CLI
remains a compatibility reference, and the six bundled dojo helpers retain their standalone
Bash fallback. SessionStart and title hooks delegate to Rust in native sessions so state
is parsed structurally and bootstrap uses the same lock. Curricula, reference implementations,
hook policies, benchmark programs and forge templates are not rewritten in this increment.

Implemented:

- Native `run`, `install`, `uninstall`, `list`/`ls`, `update`, `registry`, `new` and `help`.
- Native `state` with explicit plugin/project context and per-dojo `brk.json` configuration.
- Native `hook session-start` and `hook title`, preserving existing context text and
  using structured state snapshots instead of regex parsing.
- JSON parsing/serialization, preservation of unknown progress fields, atomic replacement
  and a stable per-project lock for native read-modify-write operations.
- Compatibility tests against the old helpers across all 64 curriculum steps.
- Source installation with a locked Cargo build and replacement only after build success.

## Build and distribution

```sh
cargo build --locked
./target/debug/brk help
./target/debug/brk list
./target/debug/brk run replicant ./my-workshop
```

Rust/Cargo >= 1.89 is required to build. Node is only required for the legacy CLI,
compatibility tests and dojos that teach JavaScript/TypeScript. Ruby, Git, the external
plugin client, Docker and other teaching dependencies remain applicable.

`install.sh` pulls this checkout, builds with Cargo.lock, installs `bin/brk`, then links
`~/.local/bin/brk` (or `BRK_BIN_DIR`). A failed build leaves the installed executable intact.
There are no prebuilt releases or runtime downloads yet.

The binary needs the plugin directories on disk. It uses an explicit `BRK_HOME` when set;
otherwise it searches ancestors of its actual executable path. Invalid explicit content
fails without fallback. A binary copied away from its content requires `BRK_HOME`; it never
silently uses the build machine's checkout or the caller's working directory.

`brk update` refreshes registry content and prints a rebuild reminder. It does not rebuild
or replace the currently running executable. Re-run `install.sh` when source changes need
to be compiled. Binary/content release pairing and automatic rollback are future work.

## Shared state protocol

```sh
brk state --plugin-root ./dojos/replicant --project-dir ./my-workshop status
brk state --plugin-root ./dojos/replicant --project-dir ./my-workshop advance
```

Plugin context: `--plugin-root`, then `CLAUDE_PLUGIN_ROOT` (required).
Project context: `--project-dir`, then `CLAUDE_PROJECT_DIR`, then cwd.

Commands: `get`, `title [step]`, `mode`, `set-mode [value]`, `advance`, `status`.
Code dojos additionally expose `spine [step]` and `kind [step]`.

Schema 1 configuration:

```json
{
  "schema_version": 1,
  "state_dir": ".replicant",
  "modality": "code",
  "initial_mode": "local-jailed",
  "initial_spine": "workspace/node.rb"
}
```

Interview configuration uses `modality: "interview"`, `initial_mode: "conversation"`,
and omits `initial_spine`. Existing progress modes remain arbitrary strings, including
legacy `interview`. C10K adds `initial_extra: {"tier":"none"}`; advance retains its
legacy tier-reset behavior. Other unknown fields survive native mutations.

Code TSV rows have four columns: number, title, spine, kind. Interview rows have three:
number, title, kind. Tables must be ordered, contiguous and nonempty. A `-` spine is
returned literally by lookup and becomes `workspace/` when advance updates progress.
Missing numeric lookups return empty stdout. `status` returns the original valid bytes.

Exit status is 0 for success, 1 for data/I/O errors, and 2 for invalid usage. Data errors
are reported on stderr; malformed progress is not silently reset or rewritten. Advance
from the final step is rejected without changing progress, rather than creating a
nonexistent curriculum step. This increment does not introduce a completion command or
an automated learning-assessment gate.

Writes use a tempfile in the same state directory, sync it, atomically replace progress,
and sync the directory. `progress.lock` stays in place to preserve lock identity. Existing
state/lock symlinks and detected spine path escapes are rejected; this is data-integrity
validation, not an OS sandbox or protection against a hostile process racing path changes.

## Compatibility boundary

Native sessions set `BRK_RUNTIME_BIN` only for a plugin with `brk.json`. The existing
`bin/dojo.sh` delegates to that executable, preserving all Markdown consumers and the
watch prompt. Without the variable, plugins remain self-contained and use Bash. External
plugins and generated dojos without native configuration remain on their old path.

SessionStart and title have native implementations behind their existing shell entrypoints.
Their shared state snapshots use structured JSON; native bootstrap uses the progress lock.
Pedagogical text is preserved in `hooks/session-context.txt` and, where applicable,
`hooks/setup-context.txt`. The `hooks` object in `brk.json` declares tooling warnings,
setup file/directory checks and title prefixes. Interpolation does not execute shell code.
Native checks use the explicit project directory instead of assuming cwd is that project.

Guard and post-benchmark implementations remain Bash. Standalone shell state writers still
do not participate in the native lock or preserve unknown JSON fields; do not concurrently
mix shell-only and native sessions on one project. The title cache retains the existing
project-wide semantics, rather than adding per-session cache behavior in this increment.

## Deliberate CLI corrections

- First use clones an absent external registry; existing caches are used without a pull.
  `update` explicitly refreshes them. Bundled dojos never require registry network access.
- Registry aliases reject traversal and collisions, including case-insensitive collisions.
- Cache metadata in `.git/brk-source.json` binds the exact configured location to its clone.
  Reusing an alias for another origin fails on use/update without deleting the old cache;
  choose another alias or manually move the old cache aside. Legacy caches are validated
  against local `remote.origin.url` once before recording metadata. Equivalent URL spellings
  are not normalized. Marked offline reads execute no Git; updates additionally check the
  current origin. Manual local cache tampering is not a security boundary.
- Plugin source paths cannot escape a registry, including detected symlink escapes.
- A failed marketplace add aborts installation; failed spawns no longer report success.
- Update failures produce a nonzero aggregate status.
- `run ... -- <args>` forwards all following arguments, including `--watch` and `-w`.
- Configured interview dojos reject watch because they have no spine helper.
- Watch remains the existing in-session `/loop` prompt, not a new background service.

Uninstall still resolves through the configured catalog. Removal by installed identity
when its registry has disappeared is not implemented in this increment.

## Verification

```sh
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked
cargo build --locked
BRK_TEST_BIN="$PWD/target/debug/brk" node --test test/*.test.js
node --test test/*.test.js
```

Tests isolate project/config/cache paths and replace the external plugin client. Native
regressions cover subprocess failure, signals, first-use clone and offline cache use,
content relocation, traversal, installer failure preservation, unknown state fields,
malformed JSON, all bundled step transitions and concurrent native advances. Hook tests
compare both implementations for all six dojos and cover nested state keys, escaped modes
and paths, separate cwd/project paths, and concurrent SessionStart plus advance. Installer
contract tests stub Cargo in a disposable checkout; Cargo build validates real compilation
separately. CI targets Linux and macOS using the minimum supported Rust version.

## Follow-up increments

1. Move guard and post-benchmark payload parsing onto the shared runtime, preserving
   per-dojo policies; decide standalone runtime distribution before removing Bash.
2. Add deterministic content validation and forge materialization.
3. Consolidate documentation recipes and launchers.
4. Correct benchmark measurement contracts, then migrate orchestration and load clients.
5. Introduce versioned prebuilt binary/content packages and update/rollback support.

The migration does not change the languages taught by the dojos or claim stronger network
isolation. Those are separate product and security decisions.
