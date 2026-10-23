# GIVEN — the wire format between nodes and clients: one JSON object per line over TCP.
# (Build-mode replicant has the learner hand-roll length-prefixed framing; lead mode starts past it.)
require "json"
require "socket"

module Wire
  def self.send_msg(sock, obj)
    sock.write(JSON.generate(obj) + "\n")
  end

  def self.recv_msg(sock)
    line = sock.gets or return nil
    JSON.parse(line)
  end

  # One request/response round trip to a node on localhost. Raises on connect/read timeout.
  def self.call(port, obj, timeout: 5)
    Socket.tcp("127.0.0.1", port, connect_timeout: timeout) do |sock|
      sock.timeout = timeout
      send_msg(sock, obj)
      recv_msg(sock) or raise IOError, "node #{port} closed the connection"
    end
  end
end
