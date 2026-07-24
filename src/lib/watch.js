// The canonical auto-review prompt seeded by `brk run --watch`.
//
// It's a `/loop` invocation because that's Claude Code's only supported way to
// let a session schedule its own future wake-ups (dynamic, self-paced) — there
// is no external "file changed" trigger that can drive an interactive session.
// So the tutor polls its own workspace and reviews in-session, keeping one
// shared conversation context.
//
// The prompt is deliberately dojo-agnostic: it resolves the current step's spine
// via the uniform `$CLAUDE_PLUGIN_ROOT/bin/dojo.sh spine` helper and gates on the
// file's mtime, so it works for every dojo (and any the forge generates later)
// with zero per-dojo wiring. The mtime gate keeps idle wakes cheap — Claude
// remembers the last-seen mtime in the conversation and stays silent until it
// changes.
export const WATCH_LOOP_PROMPT = `/loop You are running an automatic code-review watch ALONGSIDE normal tutoring. The learner drives the lesson with /start, /next, /hint, etc.; your ONLY job in this loop is to watch their work and review it the moment they save. On each wake: run \`"$CLAUDE_PLUGIN_ROOT/bin/dojo.sh" spine\` to get the current step's spine file path, then check its modification time (e.g. \`stat\`). If that file is missing, empty, or its mtime is unchanged since your last check, do nothing except schedule the next wake — stay completely silent. If the mtime changed, read the spine and review it against the current step's Gotchas, then run the step's Success-check commands and report pass/fail with specific line-level notes. NEVER write or edit the spine yourself — only the learner types it; you review it. Pace yourself dynamically: about 90 seconds between wakes while the learner is actively editing, stretching toward several minutes when nothing is changing. Keep each review short. If the learner sends you a message, handle it normally and then resume watching.`;
