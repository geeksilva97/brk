# Ruby TCP sockets — the cheatsheet (API surface only)

This is the raw socket **API surface** you're given. It is NOT the framing loop — turning this byte
stream into whole messages is *your* job (that's the lesson of Step 2). Everything here is Ruby
stdlib (`require "socket"`); the full `ri` dumps are in `docs/ri-TCPServer.txt`, `ri-TCPSocket.txt`,
`ri-IO.txt`.

## Listening (the server side)

```ruby
require "socket"

server = TCPServer.new("127.0.0.1", 9001)   # bind + listen on a port
client = server.accept                        # BLOCK until a peer connects; returns a TCPSocket
# ... talk to `client` ...
client.close
server.close
```

`accept` returns one connected `TCPSocket` per incoming connection. Call it in a loop (and/or a
thread per connection) to serve many peers.

## Connecting (the client / peer side)

```ruby
sock = TCPSocket.new("127.0.0.1", 9001)      # connect to a listener
sock.write(bytes)                             # send
reply = sock.read(n)                          # receive (see below!)
sock.close
```

## Reading bytes — READ THIS CAREFULLY, it's the whole point of Step 2

TCP is a **byte stream, not a message stream.** The bytes you `write` in one call may arrive split
across several reads, or several writes may arrive coalesced into one read. The socket preserves
*bytes and order*, never *message boundaries*. Your two reading primitives:

| Call | Behaviour |
|---|---|
| `io.read(n)` | Tries to read **exactly `n`** bytes, blocking until it has them. Returns a string of length `n`; returns a **shorter** string only if EOF is hit partway, and `nil` if already at EOF before any byte. Good when you already know how many bytes you want. |
| `io.readpartial(maxlen)` | Returns as soon as **any** data is available — between 1 and `maxlen` bytes, whatever the OS has buffered right now. Raises `EOFError` at end of stream. This is the call that exposes the stream nature: you never know how much you'll get. |

- `io.write(str)` writes all the bytes of `str` and returns the count.
- Set binary mode when you care about exact bytes: `sock.binmode` (sockets are binary by default, but
  be explicit when mixing with files).
- Always `close` sockets you're done with — a leaked socket is a leaked file descriptor.

## What you must NOT expect the socket to do for you
- It will **not** tell you where one message ends and the next begins.
- It will **not** guarantee your 8-byte write arrives as one 8-byte read.

Designing a rule that recovers message boundaries from the stream (a length prefix, a delimiter, …)
is exactly the spine you write. Don't look for a stdlib call that does it — there isn't one that
knows your protocol.
