# Step 7 reference — production-grade preforking ("the unicorn thing").
#
# This marries the Step-6 master (signals + reaping + respawn) with the Step-2
# Rack-over-a-raw-socket serving, then adds the three things that separate a toy
# preforker from Unicorn:
#
#   1. HEARTBEATS + TIMEOUT KILL. Each worker touches a per-worker heartbeat file
#      before it starts handling a request. The master checks the mtimes on a
#      timer; any worker whose heartbeat is older than TIMEOUT is wedged (stuck on
#      a bad request) — the master SIGKILLs it and respawns. SIGCHLD reaping then
#      replaces it like any other death.
#
#   2. GRACEFUL SHUTDOWN (QUIT). The master tells workers to stop accepting NEW
#      connections, finish whatever request is in flight, then exit. TERM/INT is
#      the fast path (die now); QUIT is the graceful path.
#
#   3. USR2 ZERO-DOWNTIME RESTART. On USR2 the master re-execs a brand-new master,
#      PASSING THE LISTENING SOCKET FD across the exec (the fd survives because we
#      clear close-on-exec and hand the number through an env var). The new master
#      boots on the SAME socket — no EADDRINUSE, no dropped connections — and the
#      old master then gracefully drains its workers and exits. fd inheritance is
#      the whole trick, and the hardest part of the family.
#
# Run:   bundle exec ruby workspace/unicorn_like.rb
# Then:  kill -USR2 <master>   # zero-downtime restart
#        kill -QUIT <master>   # graceful shutdown
require 'socket'
require 'rack'
require 'protocol/http1'
require 'protocol/http/body/buffered'
require_relative 'rack_env'

HOST     = ENV.fetch('HOST', '127.0.0.1')
PORT     = Integer(ENV.fetch('PORT', '4000'))
WORKERS  = Integer(ENV.fetch('WORKERS', '4'))
TIMEOUT  = Integer(ENV.fetch('TIMEOUT', '15'))    # seconds before a worker is "wedged"
HEARTBEAT_DIR = ENV.fetch('HEARTBEAT_DIR', '/tmp')

# --- acquire the listening socket --------------------------------------------
# On a normal boot we open a fresh socket. On a USR2 re-exec the previous master
# handed us the fd number in PROCESS_DOJO_FD — adopt it instead of binding again,
# so we keep serving the in-flight listener with zero downtime.
if (inherited = ENV['PROCESS_DOJO_FD'])
  server = TCPServer.for_fd(Integer(inherited))
  warn "master #{Process.pid} adopted inherited socket fd #{inherited}"
else
  server = TCPServer.new(HOST, PORT)
end
# The fd must survive exec() for USR2 to work — clear close-on-exec.
server.close_on_exec = false

app, _ = Rack::Builder.parse_file('config.ru')

# --- self-pipe (same trick as Step 6) ----------------------------------------
SELF_READ, SELF_WRITE = IO.pipe
SIGNAL_QUEUE = []
%w[CHLD TERM INT QUIT USR2].each do |sig|
  trap(sig) do
    SIGNAL_QUEUE << sig
    SELF_WRITE.write_nonblock('.') rescue nil
  end
end

worker_pids = []          # pid => true; the live worker pool
heartbeats  = {}          # pid => heartbeat file path
running     = true        # false once we begin shutting down
graceful    = false       # true on QUIT (drain) vs TERM (immediate)

def heartbeat_path(dir, pid)
  File.join(dir, "demonkey-worker-#{pid}.heartbeat")
end

# ---- the worker -------------------------------------------------------------
# Serves the Rack app on the shared socket, touching its heartbeat each request.
# Honors QUIT (finish current request, then stop) and TERM (stop accepting now).
def run_worker(server, app, port, heartbeat)
  alive = true
  draining = false
  # Worker's own signal handling: QUIT = drain, TERM/INT = stop accepting.
  trap('QUIT') { draining = true }
  trap('TERM') { alive = false }
  trap('INT')  { alive = false }
  trap('USR2', 'IGNORE')   # USR2 is the master's concern, not the worker's
  trap('CHLD', 'DEFAULT')

  while alive && !draining
    # Touch the heartbeat BEFORE blocking on accept and before each request, so a
    # worker wedged inside app.call has a stale mtime the master can detect.
    FileUtils_touch(heartbeat)

    # Don't block forever in accept — wake every second to re-check our flags
    # (so QUIT/TERM are honored even with no traffic).
    ready = IO.select([server], nil, nil, 1)
    next unless ready

    begin
      socket, _ = server.accept_nonblock
    rescue IO::WaitReadable, Errno::EAGAIN
      next
    end

    handle_connection(socket, app, port, heartbeat)
  end
end

# A minimal File.touch (avoid requiring fileutils just for this).
def FileUtils_touch(path)
  now = Time.now
  File.open(path, 'w') {}
  File.utime(now, now, path)
rescue SystemCallError
end

def handle_connection(socket, app, port, heartbeat)
  connection = Protocol::HTTP1::Connection.new(socket)
  while connection.persistent
    FileUtils_touch(heartbeat)   # progress marker per request
    authority, method, path, version, headers, body = connection.read_request
    break unless method

    env = build_env(
      method: method, path: path, version: version,
      authority: authority, headers: headers, body: body, port: port,
    )
    status, response_headers, response_body = app.call(env)
    response_headers = response_headers.reject do |name, _|
      %w[content-length transfer-encoding connection].include?(name.to_s.downcase)
    end
    connection.write_response(version, status, response_headers)
    connection.write_body(version, Protocol::HTTP::Body::Buffered.wrap(response_body), method == "HEAD")
    response_body.close if response_body.respond_to?(:close)
  end
rescue Protocol::HTTP1::Error, EOFError
ensure
  connection&.close
end

# ---- the master -------------------------------------------------------------
def spawn_worker(server, app, port, heartbeats)
  pid = fork do
    SELF_READ.close rescue nil
    SELF_WRITE.close rescue nil
    hb = heartbeat_path(HEARTBEAT_DIR, Process.pid)
    run_worker(server, app, port, hb)
    exit 0
  end
  heartbeats[pid] = heartbeat_path(HEARTBEAT_DIR, pid)
  FileUtils_touch(heartbeats[pid])    # seed so a slow boot isn't a false timeout
  pid
end

def maintain_pool(worker_pids, want, server, app, port, heartbeats)
  while worker_pids.size < want
    worker_pids << spawn_worker(server, app, port, heartbeats)
  end
end

def reap_dead(worker_pids, heartbeats)
  loop do
    begin
      pid, _ = Process.wait2(-1, Process::WNOHANG)
    rescue Errno::ECHILD
      break
    end
    break unless pid
    worker_pids.delete(pid)
    if (hb = heartbeats.delete(pid)) && File.exist?(hb)
      File.unlink(hb) rescue nil
    end
  end
end

# Kill workers whose heartbeat is older than TIMEOUT (wedged on a bad request).
def kill_wedged(worker_pids, heartbeats, timeout)
  now = Time.now
  worker_pids.dup.each do |pid|
    hb = heartbeats[pid]
    next unless hb && File.exist?(hb)
    age = now - File.mtime(hb)
    if age > timeout
      warn "worker #{pid} wedged (#{age.round}s > #{timeout}s) — SIGKILL"
      Process.kill('KILL', pid) rescue nil
      # SIGCHLD will fire and reap_dead/maintain_pool will replace it.
    end
  end
end

# USR2: re-exec a fresh master on the SAME socket fd, then drain ourselves.
def reexec(server)
  fd = server.fileno
  warn "USR2: re-exec new master on inherited fd #{fd}"
  env = ENV.to_h.merge('PROCESS_DOJO_FD' => fd.to_s)
  # Spawn the replacement master; hand it the open fd (fd => fd keeps it open
  # across exec). We do NOT use exec() in-place because we still want to drain
  # our own workers gracefully before exiting.
  child = spawn(env, RbConfig.ruby, $PROGRAM_NAME, fd => fd)
  child
end

maintain_pool(worker_pids, WORKERS, server, app, port = PORT, heartbeats)
warn "master #{Process.pid} up: #{worker_pids.size} workers on #{PORT} (timeout #{TIMEOUT}s)"

reexec_child = nil

while running || !worker_pids.empty?
  IO.select([SELF_READ], nil, nil, 1)
  begin
    SELF_READ.read_nonblock(256)
  rescue IO::WaitReadable, EOFError
  end

  while (sig = SIGNAL_QUEUE.shift)
    case sig
    when 'CHLD'
      reap_dead(worker_pids, heartbeats)
      maintain_pool(worker_pids, WORKERS, server, app, PORT, heartbeats) if running

    when 'TERM', 'INT'           # fast shutdown: kill workers now
      warn "#{sig}: immediate shutdown"
      running = false
      worker_pids.each { |pid| Process.kill('TERM', pid) rescue nil }

    when 'QUIT'                  # graceful shutdown: let workers drain
      warn "QUIT: graceful shutdown (draining #{worker_pids.size} workers)"
      running = false
      graceful = true
      worker_pids.each { |pid| Process.kill('QUIT', pid) rescue nil }

    when 'USR2'                  # zero-downtime restart
      if reexec_child.nil?
        reexec_child = reexec(server)
        # New master is now accepting on the shared socket. Drain ourselves:
        # stop respawning and tell our workers to finish in flight, then exit.
        running = false
        graceful = true
        worker_pids.each { |pid| Process.kill('QUIT', pid) rescue nil }
      end
    end
  end

  # Periodic master housekeeping while we're still up.
  if running
    kill_wedged(worker_pids, heartbeats, TIMEOUT)
  else
    # While shutting down, keep reaping drained workers.
    reap_dead(worker_pids, heartbeats)
  end
end

Process.detach(reexec_child) if reexec_child
warn "master #{Process.pid} exiting"
