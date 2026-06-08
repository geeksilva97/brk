# Step 2 reference — serve a Rack app over a raw socket, single connection at a time.
# parser (protocol-http1, a black box) + env adapter (rack_env.rb) + the app.
require 'socket'
require 'rack'
require 'protocol/http1'
require 'protocol/http/body/buffered'
require_relative 'rack_env'

HOST = ENV.fetch('HOST', '127.0.0.1')
PORT = Integer(ENV.fetch('PORT', '4000'))

app, _ = Rack::Builder.parse_file('config.ru')
server = TCPServer.new(HOST, PORT)
puts "listening on #{PORT}"

Socket.accept_loop(server) do |socket|
  connection = Protocol::HTTP1::Connection.new(socket)

  while connection.persistent
    authority, method, path, version, headers, body = connection.read_request
    break unless method

    env = build_env(
      method: method, path: path, version: version,
      authority: authority, headers: headers, body: body, port: PORT,
    )

    status, response_headers, response_body = app.call(env)

    # The parser owns framing — strip any framing headers the app set.
    response_headers = response_headers.reject do |name, _|
      %w[content-length transfer-encoding connection].include?(name.to_s.downcase)
    end

    connection.write_response(version, status, response_headers)
    connection.write_body(version, Protocol::HTTP::Body::Buffered.wrap(response_body), method == "HEAD")
    response_body.close if response_body.respond_to?(:close)
  end
rescue Protocol::HTTP1::Error, EOFError
  # client went away or sent garbage — just drop this connection
ensure
  connection&.close
end
