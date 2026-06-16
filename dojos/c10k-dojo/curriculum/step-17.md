---
step: 17
title: Benchmark everything
chapter: "18-20"
session: 5
spine: "-"
kind: bench
reference: rack_based_servers/server.rb
---

# Step 17 — Benchmark everything + the money chart

## Frame
You've built fork, preforking, thread-pool, async, and a Ractor toy — all serving the *same* Rack
app. Now run them all through the same cage and assemble the one artifact that makes the whole course
click: a chart of concurrent connections held vs survival/RSS, per model.

## The run
For each server file you built, `/c10k-dojo:bench` at the appropriate tier, then `/c10k-dojo:status`
to render the comparison table and the connections-vs-survival curve. Expect, on 1 vCPU / 256 MB:

| Model | Caps ~ | Failure mode |
|---|---|---|
| fork-per-conn | 150–400 | OOM-killed (137) |
| preforking-N | N workers | accept-queue backup → refused |
| thread-pool | pool size held | latency cliff |
| **async/fiber** | **~50,000** | graceful (FD/buffer) — **wins** |
| ractor | experimental | sharing errors |

## The discussions (no code)
- **Signal protocols compared (Ch18):** `TERM`/`HUP`/`USR2` across Unicorn vs Puma vs Falcon — a
  side-by-side table that exists nowhere else.
- **Choosing (Ch19):** a decision tree for a real Rails/Sinatra app (mostly I/O-bound → threads or
  fibers; CPU-heavy → add processes/Ractors). Benchmark the *right* thing (held connections vs req/s
  vs p99); avoid coordinated omission.
- **What we didn't build (Ch20):** HTTP/2, TLS termination, `rack.hijack`, websockets, request
  streaming — and where to read next (the real Unicorn/Puma/Falcon source, now legible).

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** Looking at your own results table, why did async win C10K while fork couldn't clear
Bronze, despite both being "concurrent"?

A good answer covers: per-connection cost: fork = a whole process (RAM cliff); async = a cheap fiber
on one thread (flat). C10K is about cheap idle concurrency, which only the fiber model delivers here.

## Wrap
Congratulate the learner: they beat C10K from raw sockets, understanding every layer — and they felt
exactly where each concurrency model lives and dies. That lived understanding is the deliverable.
