# The reactor loop — a worked shape (GIVEN, not derived)

You are **not expected to invent the `IO.select` calling convention** from scratch. This is the
black box: a complete, worked example of the readiness-multiplexing shape. In the curriculum you
copy this *shape* and fill in the application logic (the spine); you do not derive the API.

`IO.select(readers, writers, errors, timeout)` blocks until one or more of the fds in `readers` is
readable (or in `writers` is writable, etc.), then returns `[ready_to_read, ready_to_write, errored]`.
A reactor is one loop around that call.

## The canonical single-threaded reactor skeleton

```ruby
require "socket"

server = TCPServer.new(host, port)   # the listening socket is itself "readable" when a client waits
clients = {}                          # io => per-connection state (e.g. buffered bytes)

loop do
  # 1. Ask the kernel: which fds are ready? Block here and ONLY here.
  readable, _writable, _errored = IO.select([server, *clients.keys], nil, nil)

  readable.each do |io|
    if io == server
      # 2. The listener is readable => a new connection is waiting. accept WITHOUT blocking.
      client = server.accept_nonblock(exception: false)
      clients[client] = +"" unless client == :wait_readable
    else
      # 3. A client socket is readable => read what's available WITHOUT blocking.
      begin
        chunk = io.read_nonblock(4096)
        handle(io, chunk, clients)        # <-- YOUR application logic goes here (the spine)
      rescue IO::WaitReadable
        next                              # spurious wakeup; nothing to read yet
      rescue EOFError, Errno::ECONNRESET
        io.close                          # client hung up
        clients.delete(io)
      end
    end
  end
end
```

## The three rules that make it a reactor (not a blocking server)

1. **`IO.select` is the only place you wait.** Every socket op is nonblocking (`accept_nonblock`,
   `read_nonblock`, `write_nonblock`). If you ever call a *blocking* `accept`/`read`, one slow client
   freezes every other connection — that is the bug the whole course is about.
2. **State lives in a hash keyed by the IO**, not on the call stack. One thread, many half-finished
   conversations: the loop must remember where each connection was.
3. **A closed/EOF socket must be removed from the set** before the next `IO.select`, or select keeps
   reporting it ready and you spin.

## Writes that would block

If `write_nonblock` raises `IO::WaitWritable`, you can't push all the bytes yet. Buffer the rest and
add the socket to the **writers** array of `IO.select` until it drains. (Steps that need this will say
so; the simplest echo step can often write straight back.)
