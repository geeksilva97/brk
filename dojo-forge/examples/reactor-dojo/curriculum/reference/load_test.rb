# Step 6 reference (GIVEN) — open N connections, send one line on each, count how many
# the single-threaded reactor echoes back. Demonstrates capacity, not throughput.
#
#   ulimit -n 10000 && ruby workspace/reactor_writes.rb   # in one shell
#   ruby curriculum/reference/load_test.rb 5000           # in another
require "socket"

HOST = ENV.fetch("HOST", "127.0.0.1")
PORT = Integer(ENV.fetch("PORT", "3000"))
N    = Integer(ARGV[0] || "5000")

socks = []
opened = 0
begin
  N.times do |i|
    s = TCPSocket.new(HOST, PORT)
    s.write("conn-#{i}\n")
    socks << s
    opened += 1
  end
rescue Errno::EMFILE
  warn "hit the open-file limit at #{opened} connections — raise it: ulimit -n 10000"
end

echoed = 0
socks.each do |s|
  ready, = IO.select([s], nil, nil, 5)
  next unless ready
  line = s.gets
  echoed += 1 if line && line.start_with?("conn-")
rescue StandardError
  # connection dropped
end

puts "opened=#{opened} echoed=#{echoed} (held on a single-threaded reactor)"
socks.each { |s| s.close rescue nil }
