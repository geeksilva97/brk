# Step 2 reference — wait on the listener with IO.select, accept nonblocking. Single-shot echo.
require "socket"

HOST = ENV.fetch("HOST", "127.0.0.1")
PORT = Integer(ENV.fetch("PORT", "3000"))

server = TCPServer.new(HOST, PORT)
puts "listening on #{PORT}"

loop do
  readable, = IO.select([server], nil, nil)   # the ONLY blocking call
  next unless readable&.include?(server)

  client = server.accept_nonblock(exception: false)
  next if client == :wait_readable             # spurious wakeup, nothing to accept

  begin
    data = client.read_nonblock(4096, exception: false)
    client.write(data) if data.is_a?(String)
  rescue IO::WaitReadable
    # nothing ready yet
  ensure
    client.close
  end
end
