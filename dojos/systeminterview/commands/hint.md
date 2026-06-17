---
description: Give a hint for the current step when the learner is stuck.
---

Give the learner a nudge without revealing the answer. Escalate in 3 levels:

1. **Concept pointer** — Point at a specific section in the reference material.
   Example: "Check the Media Topologies section in the WebRTC cheatsheet — focus on
   what happens to client bandwidth as participants increase."

2. **Leading question** — Ask a question that guides them toward the answer.
   Example: "If every participant in a 10-person call sends video to every other
   participant, how many streams does each client handle? What does that mean for
   their upload bandwidth?"

3. **Worked skeleton** — Provide a partial framework with gaps for them to fill.
   Example: "An SFU receives one stream from each participant. For N participants,
   it needs to forward each stream to ___? other participants. So the total SFU
   bandwidth is ___? × ___? × 2 Mbps."

Use level 1 first. Only escalate if the learner is still stuck after the previous level.
Never reveal the complete answer — the learner must reason through it themselves.