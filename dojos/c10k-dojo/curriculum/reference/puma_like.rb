# Step 9 reference — Puma-like thread pool.
# One acceptor (main thread) pushes accepted sockets onto a bounded queue; a fixed
# pool of worker threads pops and serves. A held/slow connection OCCUPIES a worker
# (blocked in read_request), so the pool can only hold ~POOL active + the queue +
# the kernel backlog — then it refuses. That ceiling is the lesson.
require 'socket'
require 'rack'
require 'protocol/http1'
require 'protocol/http/body/buffered'
require_relative 'rack_env'

HOST = ENV.fetch('HOST', '127.0.0.1')
PORT = Integer(ENV.fetch('PORT', '4000'))
POOL = Integer(ENV.fetch('POOL', '16'))

app, _ = Rack::Builder.parse_file('config.ru')
server = TCPServer.new(HOST, PORT)
queue  = SizedQueue.new(1024)        # bounded → backpressure (acceptor blocks when full)
puts "listening on #{PORT} (pool=#{POOL})"

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

POOL.times do
  Thread.new do
    loop { serve(queue.pop, app, PORT) }
  end
end

loop { queue.push(server.accept) }   # acceptor
