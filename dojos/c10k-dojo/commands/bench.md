---
description: Run the constrained benchmark against the learner's current server and record the result.
---

Stress the learner's current server inside the cgroup-constrained container and grade it against
the tier.

1. Resolve the current step's spine file and kind:
   - `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" spine` → the server file (e.g. `workspace/falcon_like.rb`)
   - `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" kind`  → `tcp` (holder only) or `http` (holder + oha)
2. Pick the tier to attempt (default Bronze for early steps; Silver from Step 9; Gold optional at 13).
3. Run the harness from the learner's project dir:
   `"${CLAUDE_PLUGIN_ROOT}/env/bench/run.sh" <spine_file> <bronze|silver|gold>`
   It builds/uses the `ruby:4.0` image, runs the cage (`--cpus=1 --memory=256m --memory-swap=256m`),
   drives the Go holder (+ `oha` for http), samples peak RSS, watches for OOM, and prints one CSV row.
4. Read the result **with** the learner: did it hit the tier? If it failed, *why* (OOM-137 / connection
   refused / latency cliff / FD exhaustion)? Tie the failure mode back to the concurrency model — this
   is the lesson, not a chore.

The `post-bench` hook appends the row to the results table automatically. Use `/c10k-dojo:status` to
see the running comparison. If Docker isn't installed, say so — the bench can't run without it.
