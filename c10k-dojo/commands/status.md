---
description: Show dojo progress, the benchmark results table, and the connections-vs-survival curve.
---

Show the learner where they are and what they've measured.

1. Progress: run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" status` and render it readably — current step
   (with title), completed steps, tier reached, backend mode.
2. Results: read `.c10k-dojo/results.csv` in the project (created by the bench hook). Render it as a
   table: server, model, max_conns, fail_reason, req_s, p99_ms, peak_rss_mb, oom_killed.
3. The money chart: from the rows, sketch a simple ASCII plot of **max concurrent connections held**
   per server — fork cliffing at hundreds, threads at low thousands, async flat to tens of thousands.
   This single curve is the whole "why fibers win at C10K" lesson; call it out.

If `results.csv` doesn't exist yet, tell the learner to run `/c10k-dojo:bench` on a server first.
