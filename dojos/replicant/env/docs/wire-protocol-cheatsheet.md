# The wire protocol — the cheatsheet (the message envelope)

Every message a node sends — client requests, replies, and later the node-to-node traffic — travels
as **one envelope**: a Ruby `Hash` serialized to JSON, put on the wire behind a 4-byte big-endian
length prefix (see `pack-unpack-cheatsheet.md`; the framing itself is your spine in Step 2). This
file pins the *envelope shape* so everything you build interoperates. It is a contract, given — not
something to redesign each step.

## The envelope

```ruby
require "json"

msg = {
  "type"    => "ClientWrite",   # what kind of message this is (a string tag; see below)
  "corr_id" => "9f3a…",         # correlation ID: unique per request, echoed back in the reply
  "payload" => { … }            # type-specific body
}
bytes = JSON.generate(msg)      # -> a String you length-prefix and write
back  = JSON.parse(io_bytes)    # -> the Hash on the receiving side
```

- **`type`** — a short string naming the message kind. It's an **open set**: each step adds the
  types it needs. Don't try to enumerate them all up front.
- **`corr_id`** — a unique id the *sender* generates and the *receiver* copies verbatim into its
  reply, so a caller can match a response to the request it sent (responses may arrive out of order).
  `SecureRandom.hex(8)` is a fine generator.
- **`payload`** — a nested Hash whose shape depends on `type`.

## The message types you need right now (Layer 0)

| `type` | Direction | `payload` shape | Meaning |
|---|---|---|---|
| `ClientWrite` | client → node | `{ "sql" => "INSERT …", "params" => [...] }` | Ask the node to apply a write. |
| `ClientRead`  | client → node | `{ "sql" => "SELECT …", "params" => [...] }` | Ask the node to run a read. |
| `Reply`       | node → client | `{ "ok" => true, "rows" => [...] }` or `{ "ok" => false, "error" => "…" }` | The result, carrying the request's `corr_id`. |

Later layers introduce their own `type`s (for replication and coordination); when a step needs one,
it tells you the type and payload it expects. Keep the envelope generic and switch on `type`.

## Serialization choice
JSON is used here because it's human-readable when you're debugging with `nc` or a log dump. Ruby's
`Marshal` (see `docs/ri-Marshal.txt`) is an alternative that preserves Ruby types exactly; JSON is
recommended for this dojo so you can *see* your traffic. Either way, the envelope fields are the
same.

## What's yours vs. given
The envelope shape (this file) is given so your components agree. Deciding how to **frame** it on the
byte stream, how to **route** on `type`, and how to **generate/track** `corr_id`s is the code you
write.
