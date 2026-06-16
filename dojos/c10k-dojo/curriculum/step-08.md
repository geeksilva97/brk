---
step: 8
title: Threads and the GVL
chapter: 9
session: 2
spine: workspace/thread_echo.rb
kind: http
reference: rack_based_servers/server.rb
---

# Step 8 — Threads and the GVL

## Frame
Threads let one process handle many connections without copying memory. But MRI has a Global VM Lock:
only one thread runs Ruby bytecode at a time. The crucial nuance — **I/O releases the GVL, CPU work
doesn't** — is exactly what makes threads great for web servers and useless for parallel number-
crunching. We'll prove it with two endpoints.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** Ten threads each handle a request. Which workload actually runs concurrently on MRI?

A good answer covers: I/O-bound work (`/io`, sleeping/waiting on the network) — the GVL is released
during I/O. CPU-bound work (`/cpu`) is serialized by the GVL. Both do not run in parallel — not on
MRI; CPU work is GVL-pinned to one core. And it's not true that the GVL blocks everything; I/O
explicitly releases it, which is most web work.

## Spine  (`workspace/thread_echo.rb`, ~10 lines)
From the Step-2 server: in the accept loop, `Thread.new(conn) { serve(conn) }` instead of serving
inline. Reuse `build_env` from Step 2.

**Read first:** `docs/ri-dump/Thread.txt`.

## Agent role
- `[explain]` What the GVL is; the I/O-releases-it rule; why that fits web servers.
- `[review]` Are accepted connections each handed to their own thread? Any shared mutable state yet?

## Gotchas
- Default thread stack (~1 MB on glibc) — preview of the memory wall in Step 9.
- CPU-bound threads not speeding up on 1 core (that's the GVL, not a bug).

## Success check
`/c10k-dojo:bench` twice (the harness hits `/io` and `/cpu`): `/io` latency scales with concurrency
(threads help); `/cpu` does not (GVL-pinned). Make the learner predict each result first.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. The tutor keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' do NOT count. -->

**Question 1:** Unbounded `Thread.new` per connection — what breaks first at ~5,000 connections?

A good answer covers: memory — thousands of ~1 MB thread stacks exhaust RAM (OOM). It's not CPU —
idle threads cost little CPU; it's stack memory. And the GVL serializes; it doesn't deadlock here.
**Next:** Step 9 — a bounded thread pool. `/c10k-dojo:next`.
