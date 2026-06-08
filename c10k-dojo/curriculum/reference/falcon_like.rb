# Step 13 reference — Falcon-like async server.
# One process, one thread, the async fiber scheduler. Each connection becomes a
# cheap fiber (~KB, no kernel stack) multiplexed on the single thread; accept/read
# yield to the scheduler automatically. Idle/held connections cost almost nothing,
# so this holds tens of thousands on one core — the C10K win.
require 'socket'
require 'async'
require 'rack'
require 'protocol/http1'
require 'protocol/http/body/buffered'
require_relative 'rack_env'

HOST = ENV.fetch('HOST', '127.0.0.1')
PORT = Integer(ENV.fetch('PORT', '4000'))

app, _ = Rack::Builder.parse_file('config.ru')

def serve(socket, app, port)
  connection = Protocol::HTTP1::Connection.new(socket)
  while connection.persistent
    authority, method, path, version, headers, body = connection.read_request
    break unless method
    env = build_env(method: method, path: path, version: version,
                    authority: authority, headers: headers, body: body, port: port)
    status, response_headers, response_body = app.call(env)
    response_headers = response_headers.reject do |name, _|
      %w[content-length transfer-encoding connection].include?(name.to_s.downcase)
    end
    connection.write_response(version, status, response_headers)
    connection.write_body(version, Protocol::HTTP::Body::Buffered.wrap(response_body), method == "HEAD")
  end
rescue Protocol::HTTP1::Error, EOFError, IOError
ensure
  connection&.close
end

Async do |task|
  server = TCPServer.new(HOST, PORT)
  puts "listening on #{PORT} (async)"
  loop do
    socket = server.accept                 # yields to the scheduler when idle
    task.async { serve(socket, app, PORT) } # one fiber per connection
  end
end
