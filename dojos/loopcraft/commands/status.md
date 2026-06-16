---
description: Show dojo progress — current step, completed steps, and backend mode.
---

Show the learner where they are.

1. Run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" status` and render it readably: current step (with
   title), completed steps, backend mode.
2. Briefly map the road: which steps are done, which step is next, and the one capability that step
   adds (e.g. "Step 3 done — parse + execute weather; next is Step 4, inject + re-prompt").
   The arc is: Modelfile → tool definitions → parse + execute weather → inject + re-prompt →
   the agent loop → web search → skills as tools.
3. Verification is local. If the learner asks "how am I graded?", explain that
   each step has a concrete local success check in its curriculum file. The run command is:
   - Node 22–23.5: `node --experimental-strip-types workspace/agent.ts`
   - Node 23.6+: `node workspace/agent.ts`