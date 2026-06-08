# Step 4 reference — fork-per-connection echo server.
# Each accepted connection gets its own process. The parent returns to accept()
# immediately, so many clients are served at once — at the cost of one whole
# process per connection (the memory wall this step exposes).
require 'socket'

HOST = ENV.fetch('HOST', '127.0.0.1')
PORT = Integer(ENV.fetch('PORT', '3000'))

server = TCPServer.new(HOST, PORT)
puts "listening on #{PORT}"

loop do
  conn = server.accept

  pid = fork do
    server.close                     # child: drop the listening socket it inherited
    begin
      loop { conn.write(conn.readpartial(1024)) }
    rescue EOFError
    ensure
      conn.close
    end
  end

  conn.close                         # parent: drop the accepted connection
  Process.detach(pid)                # reap the child so it never becomes a zombie
end
