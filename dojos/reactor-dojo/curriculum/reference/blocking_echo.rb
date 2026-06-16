# Step 1 reference — blocking accept loop. One client at a time; a second client hangs.
require "socket"

HOST = ENV.fetch("HOST", "127.0.0.1")
PORT = Integer(ENV.fetch("PORT", "3000"))

server = TCPServer.new(HOST, PORT)
puts "listening on #{PORT}"

loop do
  client = server.accept            # blocks here until a client connects
  begin
    loop do
      data = client.readpartial(4096) # blocks here while client 1 is connected -> client 2 hangs
      client.write(data)
    end
  rescue EOFError
    # client disconnected
  ensure
    client.close
  end
end
