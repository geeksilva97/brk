---
step: 2
title: Rack app over a raw socket
chapter: 2
session: 0
spine: workspace/rack_server.rb
kind: http
reference: rack_based_servers/server.rb
---

# Step 2 — Rack app over a raw socket

## Frame
An HTTP server is three things bolted together: a **parser** (turns bytes into a request), an **env
adapter** (turns the request into a Rack `env` hash), and the **app** (turns `env` into a response).
The parser is a solved problem — we use `protocol-http1` as a black box. The *adapter* is the seam
you control, and the *concurrency model* (the rest of the course) is orthogonal to both. Today: serve
a real Rack app over the raw socket from Step 1.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** A Rack app returns `[200, {"content-type"=>"text/plain"}, ["hi"]]`. Who is responsible
for writing the `Content-Length` (or chunked `Transfer-Encoding`) header on the wire?

A good answer covers: the server/parser layer, not the app. That's why you must *strip*
`content-length`/`transfer-encoding`/`connection` from the app's headers before calling
`write_response`, or you'll emit them twice.

**Question 2:** The parser hands you `path` as `/search?q=ruby`. What does the Rack `env` need?

A good answer covers: `PATH_INFO="/search"` and `QUERY_STRING="q=ruby"` — split on the first `?`.
The query string is a separate key; many apps break otherwise. Rack apps read
`PATH_INFO`/`QUERY_STRING`; don't skip the split.

## protocol-http1 is GIVEN, not assumed
The learner is **not expected to know `protocol-http1`** — HTTP parsing is explicitly out of scope
(it's the black box). `docs/protocol-http1-cheatsheet.md` is a **complete worked example** of the
request/response cycle; the learner copies its *shape*, they don't derive the API. Tell them this up
front so they don't feel they're missing prerequisite knowledge. If they're new to it, the agent
can hand them the parser plumbing as a `[scaffold]` skeleton (see Agent role) with the seam left blank.

## Spine  (the learner types `workspace/rack_server.rb`, ~10 lines)
Type the **seam**: the accept loop that wraps each socket in a `Protocol::HTTP1::Connection` and runs
`read_request → build_env → app.call → write_response → write_body` while the connection is
`persistent`. The exact parser calls are in the cheatsheet — copy them; the *lesson* is the seam
(parser → env → app → response), not the parser's API. Reuse the Step-1 accept loop. (The `build_env`
helper is glue — let the agent write it.)

**Gems:** this is the first step that needs gems (`protocol-http1`, `rack`). `/c10k-dojo:setup`
provisioned a pinned `Gemfile` + `config.ru` and vendored them (`vendor/bundle`), so **run with
`bundle exec ruby workspace/rack_server.rb`**. If `require 'protocol/http1'` fails, re-run
`/c10k-dojo:setup` (the gem step). No `gem install` — the set is pinned (the guard hook blocks it).

**Read first:** `docs/protocol-http1-cheatsheet.md` (the parser has no `ri`!), `docs/rack-3.2-SPEC.rdoc`.

## Agent role
- `[explain]` Walk the learner through `docs/protocol-http1-cheatsheet.md` — what each of
  `Connection.new` / `persistent` / `read_request` / `write_response` / `write_body` does. The parser
  is a black box; the cheatsheet is the contract. Never guess the API; never reach for the web.
- `[scaffold]` *If the learner is new to protocol-http1:* write the connection-handling plumbing into
  `workspace/rack_server.rb` as a skeleton — the `while connection.persistent … read_request …
  write_response/write_body … ensure close` frame — but leave the seam (`# TODO: build env, call app`)
  for the learner. This keeps the lesson (the seam) with them while removing the parser as a blocker.
- `[glue]` Write `workspace/rack_env.rb` with `build_env(...)` returning a Rack-compliant env from
  `docs/rack-3.2-SPEC.rdoc` (REQUEST_METHOD, PATH_INFO/QUERY_STRING split, HTTP_HOST from authority,
  headers → `HTTP_<UPCASE_UNDERSCORE>`, `rack.input`=StringIO(body), `rack.errors`=$stderr,
  `rack.url_scheme`="http"). Boilerplate — delegate it.
- `[review]` Does the learner strip `content-length`/`transfer-encoding`/`connection` before writing?
  Does the body get `Protocol::HTTP::Body::Buffered.wrap(...)`?

## Gotchas
- Hand-rolling parsing with `String#split` — reject it; the parser exists for this.
- Double framing headers (app's `content-length` + parser's) → malformed response.
- Forgetting the `?` split → missing `QUERY_STRING`.
- Forgetting `Buffered.wrap` on the body array.

## Success check
`bundle exec ruby workspace/rack_server.rb`, then `curl -i http://127.0.0.1:4000/` →
`HTTP/1.1 200`, exactly **one** `content-length`, body `hello from rack`.
Reference (instructor): `curriculum/reference/rack_server.rb` + `rack_env.rb`.

## Consolidate (free-text questions — AFTER the success check passes)
<!-- The tutor asks these open-ended questions; the learner types their understanding.
     Scored 1–5. Feedback given. One retry if score < 3. -->

**Question 1:** When we add concurrency next, what changes in this server?

A good answer covers: only the accept-loop / how we dispatch — the app and the env adapter stay
identical. That orthogonality is the whole point of the rest of the course.
**Next:** Step 3 — make the single-server limit measurable. `/c10k-dojo:next`.
