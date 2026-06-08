# Step 1 reference — raw TCP echo server, single blocking accept loop.
# Serves exactly one client at a time: while one connection is open, accept()
# is never reached, so the next client waits in the kernel listen backlog.
require 'socket'

HOST = ENV.fetch('HOST', '127.0.0.1')
PORT = Integer(ENV.fetch('PORT', '3000'))

server = TCPServer.new(HOST, PORT)
puts "listening on #{PORT}"

loop do
  conn = server.accept
  begin
    loop do
      data = conn.readpartial(1024)  # blocks until bytes arrive
      conn.write(data)               # echo them back
    end
  rescue EOFError                    # client closed its side
  ensure
    conn.close                       # always release the fd
  end
end
