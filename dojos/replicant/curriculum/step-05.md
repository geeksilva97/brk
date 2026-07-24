---
step: 5
title: Idempotent receiver
spine: workspace/dedupe.rb
kind: build
reference: -
---

# Step 5 — Idempotent receiver

## Frame
The link drops **replies** now, so a client *must* retry — it sent a write, heard nothing, and can't
tell "lost request" from "lost reply." A naive node applies the retried write a **second** time: a
duplicate row, a double increment. Build the **idempotent receiver**: dedupe on a stable
`(client_id, request_id)`, and on a duplicate return the *cached* reply instead of re-applying.

## Teach the mechanisms
- **At-least-once delivery** — once a reply can be lost, retries are unavoidable, so every write may
  arrive more than once. The receiver, not the network, must make the *effect* happen once.
- **A stable request id** — the `request_id` stays identical across a request's retries (unlike a
  fresh `corr_id` minted per send). It's what identifies "the same logical write." See
  `docs/wire-protocol-cheatsheet.md`.
- **The dedupe cache** — a map from `(client_id, request_id)` to the reply you already produced. Seen
  key → return the stored reply, skip the apply.

## Spine  (the learner types `workspace/dedupe.rb`, ~20 lines)
Before applying a write, check the `(client_id, request_id)` cache. If present, return the cached
reply and do **not** re-apply. Otherwise apply, store the reply under that key, and return it. Wire
this into the write path from Step 3.

**Read first:** `docs/wire-protocol-cheatsheet.md`.

## Agent role
- `[explain]` The difference between `corr_id` (unique per send) and `request_id` (stable per logical
  request), and why the dedupe key must be the stable one.
- `[glue]` A client that sends writes, times out, and retries — plus a row-count check — so the
  learner can measure exactly-once. The dedupe logic is the learner's.
- `[scaffold]` (none.)
- `[review]` Are they keying on `request_id`, not `corr_id`? Do they cache and *return* the reply so a
  retry still gets an answer? Do they avoid deduping reads?

## Gotchas
- Keying on `corr_id` — it changes every retry, so nothing dedupes.
- Applying once but not caching the reply — the retry gets no answer.
- An unbounded cache that grows forever.
- Deduping reads, which is pointless work.

## Success check
Set the Link to drop ~20% of **replies**. Run the retrying client for many writes. The final row
count is **exactly** the number of distinct writes — no duplicates — even though many were sent more
than once.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Rows showed up twice in an early version — which id was the key, and why did that let the duplicate
through? Tie it to the drop rate they set.

**Quiz topic 2 — Design:**
Why must the dedupe key be *stable* across retries while `corr_id` must be *unique* per send — what
would break if you swapped their roles?

**Quiz topic 3 — Reflect:**
Explain "exactly-once effect over an at-least-once network" in your own words.

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. The transport is solid — next you give the node
a durable memory of every write: an append-only log. Then point them to **Step 6** and run
`/replicant:next`.
Next: The append-only log.
