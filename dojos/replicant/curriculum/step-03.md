---
step: 3
title: Request, response, correlation ID
spine: workspace/server.rb
kind: build
reference: -
---

# Step 3 — Request, response, correlation ID

## Frame
You can move whole messages, but they're just bytes with a boundary. Now give them *meaning*: decode
the `{type, corr_id, payload}` envelope, route a `ClientWrite` / `ClientRead` to a handler backed by a
local SQLite database, and reply with the **same** `corr_id`. This is the first thing that behaves
like a database server.

## Teach the mechanisms
- **The envelope** — `docs/wire-protocol-cheatsheet.md` pins the shape (`type`, `corr_id`, `payload`).
  Parse it with `JSON.parse` after you read a frame.
- **Routing on `type`** — a `case` over the message kind; `ClientWrite` runs an `INSERT`/`UPDATE`,
  `ClientRead` runs a `SELECT`.
- **Why echo `corr_id`?** Replies can come back in a different order than requests went out. The
  caller matches a reply to its request by the id it generated. You'll see the request's id come back
  on the reply.
- **Local SQLite** — `docs/sqlite3-ruby-cheatsheet.md`; use `?` **bind parameters**, never string
  interpolation (it also keeps the SQL text stable, which matters).

## Spine  (the learner types `workspace/server.rb`, ~25 lines)
An accept loop that, per message: reads a frame (reuse Step 2), `JSON.parse`s the envelope, `case`s on
`type`, runs the SQL on a local `SQLite3::Database` with bind params, and writes back a framed `Reply`
carrying the request's `corr_id` and the result (rows, or ok/error).

**Read first:** `docs/wire-protocol-cheatsheet.md`, `docs/sqlite3-ruby-cheatsheet.md`.

## Agent role
- `[explain]` Walk the envelope fields and the `sqlite3` `execute`/bind-param calls from the cheatsheets.
- `[glue]` A minimal client helper that sends a request and reads the reply, so the learner can
  exercise the server — the routing/handler stays the learner's.
- `[scaffold]` (none.)
- `[review]` Is `corr_id` copied verbatim onto the reply? Are they using `?` params, not interpolation?
  Does one malformed message avoid killing the whole accept loop?

## Gotchas
- Not echoing `corr_id` — the caller can't tell which reply is which.
- String-interpolating values into SQL instead of bind params.
- Assuming replies arrive in send order.
- A parse error on one message taking down the server.

## Success check
Start `server.rb`. With the client helper, send a `ClientWrite` (insert `k=name,v=ada`), then a
`ClientRead` (select `name`) → the read returns `ada`, and the `Reply`'s `corr_id` equals the read
request's `corr_id`.

The learner must explain *why* it behaves this way before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)

**Quiz topic 1 — Diagnose:**
Two requests are in flight and the replies come back swapped. How does the `corr_id` they wrote let
the caller sort it out? Ground it in the ids they saw.

**Quiz topic 2 — Design:**
Why one generic envelope with a `type` field, rather than a different message format per operation?

**Quiz topic 3 — Reflect:**
What turned "whole messages" into a request/response *protocol* — what's the minimum that made it one?

## Next step  (do NOT ask the learner to choose)
There is one logical next step; state it and advance. The node talks to clients — next it must talk
to *other nodes*, over a link you can deliberately break. Then point them to **Step 4** and run
`/replicant:next`.
Next: Peer links and the fault injector.
