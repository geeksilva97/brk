# Step 5 reference — preforking N workers.
# Open the listening socket ONCE, fork a fixed pool of workers up front, and let
# them ALL call accept() on the same inherited socket. The kernel hands each new
# connection to exactly one waiting worker (load-balanced; no thundering herd on
# modern kernels). No per-connection fork, so memory is bounded: N workers, not
# N-connections worth of processes.
require 'socket'

HOST    = ENV.fetch('HOST', '127.0.0.1')
PORT    = Integer(ENV.fetch('PORT', '3000'))
WORKERS = Integer(ENV.fetch('WORKERS', '4'))   # hardcoded N, chosen on purpose
                                               # (NOT Etc.nprocessors — web work is
                                               #  mostly waiting, so oversubscribe)

server = TCPServer.new(HOST, PORT)
puts "listening on #{PORT} (master pid #{Process.pid}, #{WORKERS} workers)"

# Each worker loops forever on the shared socket, echoing one client at a time.
def worker_loop(server)
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

WORKERS.times do
  fork do
    # Workers inherited the listening socket fd from the parent — they share it.
    worker_loop(server)
  end
end

# The parent does NOT accept. It just waits on its children so they aren't
# orphaned. (Step 6 turns this bare wait into a real supervising master.)
Process.waitall
