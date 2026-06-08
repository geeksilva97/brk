---
description: Run the memory benchmark against the current step's server and read peak RSS + OOM with the learner.
---

Run the constrained **memory** benchmark against the learner's current server and read the result
*with* them. This is NOT a throughput/C10K test — the whole point is **peak RSS** and **whether the
container got OOM-killed**, so the learner can SEE the value of preforking: fork-per-connection's
memory climbs with load until the kernel kills it, while a fixed worker pool stays flat and survives
the same load.

1. Resolve the current step's spine file and kind:
   - `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" spine` → the server file (e.g. `workspace/fork_echo.rb`).
   - `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" kind`  → `tcp` (the echo servers, Steps 1/4/5/6) or `http`
     (the Rack servers, Steps 2/7). Pass it through as `KIND=<kind>` to the harness; the demo lives
     on the **tcp** echo servers (Steps 4 vs 5).

2. Run the harness from the learner's project dir (so `.demonkey/` lands there):
   `KIND=<kind> "${CLAUDE_PLUGIN_ROOT}/env/bench/run.sh" <spine_file> [held] [mem] [cpus]`
   Defaults are `held=300 mem=192m cpus=0` — tuned so fork-per-connection OOM-kills at ~150 held
   connections in a few seconds while preforking holds all 300 flat. The container is **resource-capped
   on both axes via cgroups**: `--cpuset-cpus=<cpus>` (CPU — `0` pins to one core) and
   `--memory=<mem> --memory-swap=<mem>` (memory, swap matched so OOM isn't masked). Both are tunable
   args, so you can demo "tighten the box and watch fork die sooner." It builds/uses the `ruby:4.0`
   image, drives the Ruby holder (`env/bench/holder.rb`) to hold an accumulating wave of idle
   connections, samples peak RSS, watches for the OOM killer, and prints one `PDOJO_RESULT` row.

3. Read the result **with** the learner. Point at two numbers:
   - **peak RSS** — did it climb with the connection count (fork: a whole process per connection) or
     stay flat (prefork: a fixed N CoW-shared workers, memory independent of load)?
   - **OOM** — `oom=true` / exit 137 means the kernel OOM-killer fired: the server outgrew its memory
     budget. `oom=false` / SURVIVED means it held the load with room to spare.
   Tie it back to the concurrency model — this contrast IS the lesson, not a chore:
   - On **Step 4 (fork-per-connection)** you expect **OOM-KILLED**: a process per connection means
     memory grows with load until it blows.
   - On **Step 5 (preforking)** you expect **SURVIVED, flat RSS**: a bounded pool paid for once at
     boot, so connection count no longer drives memory. Run the SAME `held`/`mem` as Step 4 so the
     before/after is honest.

The `post-bench` hook appends the row to `${CLAUDE_PROJECT_DIR}/.demonkey/results.csv`
automatically, so the fork-vs-prefork rows sit side by side. If Docker isn't installed, say so — the
bench can't run without it. This is the only step in the pilot that uses Docker (the holder is Ruby).
