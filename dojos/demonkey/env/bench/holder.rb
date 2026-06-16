#!/usr/bin/env ruby
# holder.rb — the demonkey memory-bench load generator. Opens N connections
# and HOLDS them open (idle) so the server's per-connection cost shows up as RSS:
# fork-per-connection climbs and OOM-kills; preforking stays flat.
#
# Idle connections need no concurrency — we just open the sockets and keep them
# open — so this is plain single-threaded stdlib Ruby (no Go, no threads). At the
# few-hundred-connection scale this demo uses, that's more than enough; if you ever
# need to hold tens of thousands, that's the c10k-dojo's Go holder's job.
#
#   ruby holder.rb -addr 127.0.0.1:4000 -n 150 -hold 30s -kind tcp
#
# Prints one line:  HOLDER addr=… requested=N established=E failed=F first_error=REASON
require "socket"

opts = { addr: "127.0.0.1:4000", n: 100, hold: 30, kind: "tcp" }
args = ARGV.dup
until args.empty?
  case args.shift
  when "-addr" then opts[:addr] = args.shift
  when "-n"    then opts[:n]    = args.shift.to_i
  when "-hold" then opts[:hold] = args.shift.to_s.to_i   # "30s" -> 30
  when "-kind" then opts[:kind] = args.shift
  end
end
host, port = opts[:addr].split(":"); port = port.to_i

# Map a connect error to a short, space-free reason token (matches the old Go holder
# so run.sh's parsing and the curriculum's failure-mode language stay the same).
reason_for = lambda do |e|
  case e
  when Errno::ECONNREFUSED  then "refused"               # server gone / accept queue full
  when Errno::ETIMEDOUT     then "timeout"               # server wedged
  when Errno::ECONNRESET    then "reset"                 # reset under the connection storm
  when Errno::EADDRNOTAVAIL then "client-ephemeral-exhausted"  # OUR ports ran out, not the server's
  when Errno::EMFILE, Errno::ENFILE then "client-fd-exhausted" # OUR fd table, not the server's
  else (e.message.to_s[/reset|refused|timed?.out/i] || e.class.name).to_s.tr(" ", "-")
  end
end

established = 0
failed = 0
first_error = nil
held = []

opts[:n].times do
  begin
    sock = Socket.tcp(host, port, connect_timeout: 5)
    # For HTTP servers, send a partial request that never terminates (slowloris):
    # the server parks waiting for the rest, so the connection stays held.
    sock.write("GET /hold HTTP/1.1\r\nHost: bench\r\n") if opts[:kind] == "http"
    held << sock
    established += 1
  rescue => e
    failed += 1
    first_error ||= reason_for.call(e)
  end
end

# Hold everything open and idle for the window; the server's RSS is sampled by run.sh
# while we sleep here.
sleep opts[:hold]

puts "HOLDER addr=#{opts[:addr]} requested=#{opts[:n]} established=#{established} " \
     "failed=#{failed} first_error=#{first_error || 'none'}"

held.each { |s| s.close rescue nil }
