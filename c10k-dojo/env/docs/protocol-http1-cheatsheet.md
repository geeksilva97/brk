# protocol-http1 — the cheatsheet (you do NOT need to know this gem in advance)

`protocol-http1` is a pure-Ruby HTTP/1 parser by Samuel Williams. In this dojo it is a **black
box**: it turns the bytes on a socket into a parsed request, and turns your response into bytes.
You never parse HTTP yourself. It ships **no `ri`/rdoc**, so this file *is* the documentation —
everything you need is below. You should not have to read the gem's source (it's there if you're
curious: `gem contents protocol-http1`).

The dojo's whole thesis: **the protocol is solved (this gem); the book is concurrency.** So the
code below is *scaffolding you are given*. The part you actually author is the concurrency model
(the accept loop, fork/threads/fibers) and the env adapter — not these parser calls.

---

## The complete server-side cycle (copy this shape)

```ruby
require "socket"
require "rack"
require "protocol/http1"
require "protocol/http/body/buffered"

# 1. wrap an accepted TCP socket in a parser connection
connection = Protocol::HTTP1::Connection.new(socket)

# 2. serve requests while the connection is reusable (HTTP keep-alive)
while connection.persistent
  # 3. read & parse one request. Returns nil-ish (no method) when the client closed.
  authority, method, path, version, headers, body = connection.read_request
  break unless method

  # 4. (YOUR seam) turn the parsed request into a Rack env, call the app
  env = build_env(method:, path:, version:, authority:, headers:, body:, port: 4000)
  status, response_headers, response_body = app.call(env)

  # 5. the PARSER owns framing — strip any framing headers the app set, or you double them
  response_headers = response_headers.reject do |name, _|
    %w[content-length transfer-encoding connection].include?(name.to_s.downcase)
  end

  # 6. write the response: status line + headers, then the body
  connection.write_response(version, status, response_headers)
  connection.write_body(version, Protocol::HTTP::Body::Buffered.wrap(response_body), method == "HEAD")
end
ensure
  connection&.close
```

That ~20-line shape is the entire surface. Everything that changes between the fork/thread/fiber
servers is *around* it (how you get `socket` and how many run at once), never inside it.

---

## Method reference

| Call | What it does |
|---|---|
| `Protocol::HTTP1::Connection.new(socket)` | Wrap an accepted `TCPSocket` so you can read/write HTTP on it. |
| `connection.persistent` | `true` while the connection can serve another request (keep-alive). Loop on it. |
| `connection.read_request` | Read & parse ONE request. Returns `[authority, method, path, version, headers, body]`. Returns with `method == nil` when the client has closed — `break` then. |
| `connection.write_response(version, status, headers)` | Write the status line + headers. `version` is the string from `read_request` (e.g. `"HTTP/1.1"`). |
| `connection.write_body(version, body, head?)` | Write the body. Wrap a Rack body array with `Protocol::HTTP::Body::Buffered.wrap(...)`. Pass `true` for HEAD requests (no body). |
| `connection.close` | Release the connection. Always do this in `ensure`. |

### What `read_request` hands you
- `authority` — the `Host` header value → maps to Rack `HTTP_HOST`.
- `method`   — `"GET"`, `"POST"`, … (`nil` ⇒ client closed).
- `path`     — the request target *including* any query string. **You** split it on the first `?`
  into `PATH_INFO` + `QUERY_STRING`.
- `version`  — `"HTTP/1.1"`. Pass it back to `write_response`/`write_body`.
- `headers`  — an enumerable of `[name, value]`; names are lowercased; `host`/`content-length`/
  `transfer-encoding` are already consumed by the parser.
- `body`     — a readable body, or `nil` when there is none. `body.join` reads it all into a String.

---

## Gotchas (these are the review checklist for Step 2)
1. **Don't hand-roll parsing** with `String#split` — the parser exists exactly so you don't.
2. **Don't double-frame.** If you pass the app's `content-length`/`transfer-encoding`/`connection`
   through AND let `write_body` frame, you emit them twice → broken response. Strip them (step 5).
3. **Split the query string.** `path` is `/search?q=ruby` → `PATH_INFO="/search"`,
   `QUERY_STRING="q=ruby"`.
4. **Wrap the body.** `write_body` wants `Protocol::HTTP::Body::Buffered.wrap(rack_body)`, not the
   raw array.
5. **Close in `ensure`.** A leaked connection is a leaked fd.

If anything here is unclear, ask the tutor to explain a specific line — do not guess the API from
memory, and do not reach for the web (the dojo is offline).
