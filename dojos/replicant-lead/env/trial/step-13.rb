# Trial for Step 13 — the read gate. Owned by the plugin, never by the workspace: the agent builds
# the system, it does not get to write its own grader.
#
# Drives the learner's system only through the contract in workspace/lib/client.rb:
#   Client#write / Client#read(sql, node:)        the ungated baseline
#   Client::Session#write / #read(sql, prefer:)   what Step 13 builds
#   Client::Session#retries                       optional; counted when present
#
# Prints a human summary, then exactly one machine line:
#   TRIAL_RESULT,step=13,<key=value>,...
require "timeout"

WS = File.expand_path(ARGV.fetch(0))
$LOAD_PATH.unshift(File.join(WS, "lib"))
require "client"

FOLLOWER = 7002
CYCLES = 100
SELECT = "SELECT name FROM users WHERE id = 1".freeze

def sh(*cmd)
  system(*cmd, exception: true, out: File::NULL)
end

def link(*args) = sh(File.join(WS, "bin", "link"), *args)

def now_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)

def caught_up?(client)
  leader = client.status(Client::LEADER)["applied_index"]
  Client::FOLLOWERS.all? { |f| client.status(f)["applied_index"] >= leader }
end

def drain(client)
  sleep 0.05 until caught_up?(client)
end

def percentile(values, p)
  return 0 if values.empty?

  values.sort[((values.size - 1) * p).round].round
end

# Run `cycles` write-then-read cycles. The block does one read for value `v` and returns the rows.
def cycles(n, tag)
  stale = errors = 0
  latencies = []
  n.times do |i|
    value = "#{tag}-#{i}"
    yield(:write, value)
    t0 = now_ms
    begin
      rows = Timeout.timeout(10) { yield(:read, value) }
      latencies << now_ms - t0
      stale += 1 unless rows == [[value]]
    rescue StandardError, Timeout::Error
      errors += 1
    end
  end
  { stale: stale, errors: errors, latencies: latencies }
end

def update(value) = "UPDATE users SET name = '#{value}' WHERE id = 1"

result = { "step" => 13 }
plain = Client.new
abort "TRIAL_RESULT,step=13,error=Client::Session is not defined in workspace/lib/client.rb" unless defined?(Client::Session)

sh(File.join(WS, "bin", "cluster"), "restart")
at_exit { system(File.join(WS, "bin", "cluster"), "stop", out: File::NULL) }
link("reset")

puts "== 1. No gate, #{CYCLES} cycles, 500 ms replication delay to #{FOLLOWER}"
link(FOLLOWER.to_s, "delay", "500")
r = cycles(CYCLES, "plain") do |op, v|
  op == :write ? plain.write(update(v)) : plain.read(SELECT, node: FOLLOWER)
end
result["nogate_stale"] = "#{r[:stale]}/#{CYCLES}"
puts "   stale reads: #{r[:stale]}/#{CYCLES}"
drain(plain)

puts "== 2. Gated session, #{CYCLES} cycles, 500 ms replication delay to #{FOLLOWER}"
session = Client::Session.new
r = cycles(CYCLES, "gated") do |op, v|
  op == :write ? session.write(update(v)) : session.read(SELECT, prefer: FOLLOWER)
end
retries = session.respond_to?(:retries) ? session.retries.to_i : nil
result["gate_stale"] = "#{r[:stale]}/#{CYCLES}"
result["gate_errors"] = "#{r[:errors]}/#{CYCLES}"
result["gate_p50_ms"] = percentile(r[:latencies], 0.50)
result["gate_p99_ms"] = percentile(r[:latencies], 0.99)
result["gate_retries_per_100"] = retries.nil? ? "n/a" : (retries * 100.0 / CYCLES).round
puts "   stale reads: #{r[:stale]}/#{CYCLES}, errors: #{r[:errors]}, " \
     "p50 #{result["gate_p50_ms"]} ms, p99 #{result["gate_p99_ms"]} ms, retries/100: #{result["gate_retries_per_100"]}"
drain(plain)

puts "== 3. Gated session, 50 cycles, no replication delay but 200 ms apply delay on #{FOLLOWER}"
link(FOLLOWER.to_s, "delay", "0")
link(FOLLOWER.to_s, "apply-delay", "200")
session = Client::Session.new
r = cycles(50, "applylag") do |op, v|
  op == :write ? session.write(update(v)) : session.read(SELECT, prefer: FOLLOWER)
end
result["applylag_stale"] = "#{r[:stale]}/50"
result["applylag_errors"] = "#{r[:errors]}/50"
puts "   stale reads: #{r[:stale]}/50, errors: #{r[:errors]}"
link(FOLLOWER.to_s, "apply-delay", "0")
drain(plain)

puts "== 4. Gated session, #{FOLLOWER} fully partitioned from the leader"
link(FOLLOWER.to_s, "partition", "on")
session = Client::Session.new
session.write(update("partitioned"))
t0 = now_ms
outcome = begin
  rows = Timeout.timeout(10) { session.read(SELECT, prefer: FOLLOWER) }
  rows == [["partitioned"]] ? "fresh" : "STALE"
rescue Timeout::Error
  "hung"
rescue StandardError => e
  "error:#{e.class}"
end
result["partition"] = "#{outcome}@#{(now_ms - t0).round}ms"
puts "   outcome: #{outcome} after #{(now_ms - t0).round} ms (trial cuts off at 10000 ms)"
link("reset")

puts "TRIAL_RESULT," + result.map { |k, v| "#{k}=#{v}" }.join(",")
