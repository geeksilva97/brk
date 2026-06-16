---
description: Show dojo progress — current step, completed steps, and backend mode.
---

Show the learner where they are.

1. Run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" status` and render it readably: current step (with
   title), completed steps, backend mode.
2. Briefly map the road: which steps are done, which step is next, and the one capability that step
   adds (e.g. "Step 5 done — preforking; next is Step 6, the supervising master that respawns dead
   workers"). The arc is: socket → Rack → see-it-block → fork → preforking → master/signals →
   unicorn-like (heartbeats + graceful shutdown + USR2).
3. There is no benchmark and no results table in this pilot — verification is local (nc / ps / lsof /
   kill -SIGNAL). If the learner asks "how am I graded?", explain that each step has a concrete local
   success check in its curriculum file, not a load-test score.
