# Steps 3-4 reference — single-threaded reactor: one IO.select loop, many clients,
# with per-connection input buffering and line framing (Step 4).
require "socket"

HOST = ENV.fetch("HOST", "127.0.0.1")
PORT = Integer(ENV.fetch("PORT", "3000"))

server  = TCPServer.new(HOST, PORT)
clients = {}                       # io => input buffer (Step 4: state keyed by IO)
puts "listening on #{PORT}"

loop do
  readable, = IO.select([server, *clients.keys], nil, nil)  # the ONLY blocking call

  readable.each do |io|
    if io == server
      client = server.accept_nonblock(exception: false)
      clients[client] = +"" unless client == :wait_readable
    else
      begin
        clients[io] << io.read_nonblock(4096)
        # drain every complete line in the buffer (frame on \n, not on read boundary)
        while (idx = clients[io].index("\n"))
          line = clients[io].slice!(0..idx)
          io.write(line)
        end
      rescue IO::WaitReadable
        next
      rescue EOFError, Errno::ECONNRESET
        io.close
        clients.delete(io)         # drop dead fds before the next IO.select
      end
    end
  end
end
