# The ONE Rack app for the whole dojo. Every server you build (raw Rack, prefork,
# master, unicorn-like) serves THIS same app — so you feel the orthogonality of
# "app" vs "server": the concurrency model changes, the app never does.
#
# Endpoints chosen to exercise the process family:
#   /        — trivial, fast (sanity + throughput baseline)
#   /slow    — sleeps a few seconds (a "slow request": ties up one worker; with
#              N workers, only N of these run at once — the preforking limit)
#   /wedge   — sleeps far longer than the heartbeat TIMEOUT (Step 7: the master
#              should detect the stale heartbeat and SIGKILL+respawn the worker)
require "rack"

app = lambda do |env|
  case env["PATH_INFO"]
  when "/slow"  then sleep 3;   [200, { "content-type" => "text/plain" }, ["slow\n"]]
  when "/wedge" then sleep 120; [200, { "content-type" => "text/plain" }, ["wedge\n"]]
  else [200, { "content-type" => "text/plain" }, ["hello from rack\n"]]
  end
end

run app
