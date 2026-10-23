# Repro for Step 13's incident — the "my old name came back" ticket, live. Not gated by the hooks:
# the tutor runs it in the Frame, before any decision exists. Uses only the ungated baseline client.
WS = File.expand_path(ARGV.fetch(0))
$LOAD_PATH.unshift(File.join(WS, "lib"))
require "client"

FOLLOWER = 7002

system(File.join(WS, "bin", "cluster"), "restart", exception: true)
at_exit { system(File.join(WS, "bin", "cluster"), "stop", out: File::NULL) }
system(File.join(WS, "bin", "link"), FOLLOWER.to_s, "delay", "500", exception: true, out: File::NULL)

client = Client.new
%w[Ana Bruno Carla Davi Elisa].each do |name|
  client.write("UPDATE users SET name = '#{name}' WHERE id = 1")
  seen = client.read("SELECT name FROM users WHERE id = 1", node: FOLLOWER).dig(0, 0)
  puts format("saved %-6s -> refreshed, page shows %-8s %s", name, seen, seen == name ? "" : "<- stale")
end

system(File.join(WS, "bin", "link"), "reset", exception: true, out: File::NULL)
