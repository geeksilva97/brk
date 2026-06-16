# Reference implementations (for `/demonkey:reveal`)

`/demonkey:reveal` shows the canonical answer for a step and diffs it against the learner's
attempt. Unlike the c10k-dojo it's piloted from, **every step here has a complete, syntax-checked,
functionally-tested reference** — there is no live-demo fallback gap.

| Step | Title | Reference file | Deps |
|---|---|---|---|
| 1 | Raw TCP echo server | `echo.rb` | stdlib (`socket`) |
| 2 | Rack app over a raw socket | `rack_server.rb` + `rack_env.rb` | `rack`, `protocol-http1` |
| 3 | Why one server is not enough | *(no spine — local demo)* | — |
| 4 | Fork-per-connection | `fork_echo.rb` | stdlib |
| 5 | Preforking N workers | `prefork.rb` | stdlib |
| 6 | Master: signals & reaping | `master.rb` | stdlib |
| 7 | Production-grade preforking | `unicorn_like.rb` + `rack_env.rb` | `rack`, `protocol-http1` |

## How they were verified

Every file passes `ruby -c`. The stdlib servers (`echo`, `fork_echo`, `prefork`, `master`) were run
locally and exercised with `nc` / `ps` / `kill -SIGNAL`:
- `prefork.rb` — confirmed N worker children, two simultaneous `nc` clients echo at once.
- `master.rb` — confirmed `TTIN` adds a worker, `TTOU` removes one, `kill -9 <worker>` respawns (no
  zombies), `TERM` shuts down clean.
- `unicorn_like.rb` — confirmed heartbeat timeout SIGKILLs + respawns a `/wedge` worker; **`USR2`
  re-exec adopts the inherited socket fd and serves with zero dropped connections while a `/slow`
  request is in flight**; `QUIT` drains workers and exits clean.

## The hard one: `unicorn_like.rb`

The USR2 path is the crux of the whole course. The trick:
- `server.close_on_exec = false` so the listening fd survives `exec`,
- on `USR2`, `spawn(env, ruby, $PROGRAM_NAME, fd => fd)` hands the open fd to a fresh master and
  passes its number in `PROCESS_DOJO_FD`,
- the new master adopts it with `TCPServer.for_fd(Integer(ENV['PROCESS_DOJO_FD']))` instead of
  binding (no EADDRINUSE),
- the old master then `QUIT`s its own workers (graceful drain) and exits.

The master uses the **self-pipe trick** (traps enqueue a signal name + poke a pipe; the `IO.select`
loop does the real work safely) and reaps with `Process.wait2(-1, Process::WNOHANG)` in a loop.

**These are the instructor's escape hatch — gate `/reveal` to instructor mode if you don't want
learners skipping the struggle.**
