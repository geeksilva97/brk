# Step 5 reference — reactor with write backpressure. Reads AND writes are nonblocking;
# IO.select is the only wait point. Sockets join the writers set only while they have
# buffered output.
require "socket"

HOST = ENV.fetch("HOST", "127.0.0.1")
PORT = Integer(ENV.fetch("PORT", "3000"))

server = TCPServer.new(HOST, PORT)
conns  = {}    # io => { in: buffer, out: buffer }
puts "listening on #{PORT}"

flush = lambda do |io|
  st = conns[io]
  return if st[:out].empty?
  n = io.write_nonblock(st[:out], exception: false)
  st[:out].slice!(0, n) if n.is_a?(Integer)   # drop exactly the bytes that were sent
  # if n == :wait_writable, leave out as-is; we'll retry when select says writable
end

loop do
  writers = conns.select { |_io, st| !st[:out].empty? }.keys
  readable, writable, = IO.select([server, *conns.keys], writers, nil)

  readable.each do |io|
    if io == server
      client = server.accept_nonblock(exception: false)
      conns[client] = { in: +"", out: +"" } unless client == :wait_readable
    else
      begin
        conns[io][:in] << io.read_nonblock(4096)
        while (idx = conns[io][:in].index("\n"))
          line = conns[io][:in].slice!(0..idx)
          conns[io][:out] << line        # queue the echo
        end
        flush.call(io)
      rescue IO::WaitReadable
        next
      rescue EOFError, Errno::ECONNRESET
        io.close
        conns.delete(io)
      end
    end
  end

  writable.each { |io| flush.call(io) if conns[io] }
end
