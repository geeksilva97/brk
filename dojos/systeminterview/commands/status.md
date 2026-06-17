---
description: Show current step and progress through the systeminterview dojo.
---

Show the learner's current progress.

1. Run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" status` to get the progress state.
2. Run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" get` to get the current step number.
3. Run `"${CLAUDE_PLUGIN_ROOT}/bin/dojo.sh" title` for the current step title.
4. Display:

   Step 1: Scoping the Problem          [completed]
   Step 2: High-Level Architecture       [completed]
   Step 3: Deep Dive: Signaling & WebRTC [current]
   Step 4: Media Servers & NAT Traversal [locked]
   Step 5: Capacity Planning & Estimation [locked]
   Step 6: Recording, Multi-Region & Trade-offs [locked]
   Step 7: Wrap-Up & Self-Review         [locked]