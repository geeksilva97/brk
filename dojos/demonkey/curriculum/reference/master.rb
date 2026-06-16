# Step 6 reference — the master process: signals, reaping, respawn.
#
# A production preforking server splits into two roles:
#   * the MASTER never accept()s. It supervises: it spawns workers, replaces any
#     that die, and translates Unix signals into actions.
#   * the WORKERS do the actual accept()/serve loop on the shared socket.
#
# Two ideas carry this file:
#
# 1. SIGCHLD + Process.wait(-1, WNOHANG) reaping. When a worker dies the kernel
#    sends the master SIGCHLD. The master reaps in a NON-BLOCKING LOOP (several
#    children can die between wakeups, and one SIGCHLD may stand for many) and
#    re-forks a replacement for each.
#
# 2. The self-pipe trick. You must not do real work (fork, allocate, log) inside
#    a signal trap — handlers run at unsafe moments and async-signal-unsafe calls
#    can deadlock or corrupt. So each trap does the MINIMUM: it writes one byte to
#    a pipe. The main loop sits in IO.select on the read end; a delivered signal
#    makes the pipe readable and wakes select. All the heavy lifting happens there,
#    on the normal call stack, where it is safe.
require 'socket'

HOST    = ENV.fetch('HOST', '127.0.0.1')
PORT    = Integer(ENV.fetch('PORT', '3000'))
WORKERS = Integer(ENV.fetch('WORKERS', '4'))

server = TCPServer.new(HOST, PORT)

# --- the self-pipe -----------------------------------------------------------
# A signal makes SELF_WRITE readable; the main loop blocks on SELF_READ. We keep
# a queue of which signals fired so the main loop can dispatch them in order.
SELF_READ, SELF_WRITE = IO.pipe
SIGNAL_QUEUE = []

%w[CHLD TERM INT QUIT TTIN TTOU].each do |sig|
  trap(sig) do
    SIGNAL_QUEUE << sig          # async-signal-safe: just enqueue
    SELF_WRITE.write_nonblock('.') rescue nil  # and poke the pipe to wake select
  end
end

# --- worker bookkeeping ------------------------------------------------------
worker_pids = []                 # pids we currently expect to be alive
want_workers = WORKERS           # target count (TTIN/TTOU adjust this)
running = true

def spawn_worker(server)
  fork do
    # A fresh worker should react to TERM/QUIT itself, not inherit the master's
    # traps. Reset to default so a TERM cleanly kills the worker.
    %w[CHLD TERM INT QUIT TTIN TTOU].each { |s| trap(s, 'DEFAULT') }
    loop do
      conn = server.accept
      begin
        loop { conn.write(conn.readpartial(1024)) }
      rescue EOFError
      ensure
        conn.close
      end
    end
  end
end

# Bring the pool up to `want_workers`.
def maintain_pool(worker_pids, want, server)
  while worker_pids.size < want
    worker_pids << spawn_worker(server)
  end
end

maintain_pool(worker_pids, want_workers, server)
puts "master #{Process.pid} up: #{worker_pids.size} workers on #{PORT}"

# --- the supervising loop ----------------------------------------------------
while running
  # Block until a signal pokes the pipe (or wake periodically as a safety net).
  IO.select([SELF_READ], nil, nil, 1)
  # Drain the pipe so it doesn't stay readable.
  begin
    SELF_READ.read_nonblock(256)
  rescue IO::WaitReadable, EOFError
  end

  # Dispatch every signal that queued up since the last pass.
  while (sig = SIGNAL_QUEUE.shift)
    case sig
    when 'CHLD'
      # Reap EVERY dead child (a single SIGCHLD can cover several) and respawn.
      loop do
        begin
          pid, _status = Process.wait2(-1, Process::WNOHANG)
        rescue Errno::ECHILD
          break                  # no children left to reap
        end
        break unless pid         # WNOHANG: nothing more is dead right now
        if worker_pids.delete(pid)
          warn "worker #{pid} died"
        end
      end
      maintain_pool(worker_pids, want_workers, server) if running

    when 'TTIN'                  # add a worker
      want_workers += 1
      maintain_pool(worker_pids, want_workers, server)
      warn "TTIN -> #{want_workers} workers"

    when 'TTOU'                  # remove a worker
      if want_workers > 0
        want_workers -= 1
        victim = worker_pids.pop
        Process.kill('TERM', victim) if victim
        warn "TTOU -> #{want_workers} workers"
      end

    when 'TERM', 'INT', 'QUIT'   # shut the whole thing down
      warn "#{sig}: shutting down #{worker_pids.size} workers"
      running = false
      worker_pids.each { |pid| Process.kill('TERM', pid) rescue nil }
    end
  end
end

# Reap the workers we just signalled so we exit clean (no zombies).
worker_pids.each { |pid| Process.wait(pid) rescue nil }
puts "master #{Process.pid} exiting"
