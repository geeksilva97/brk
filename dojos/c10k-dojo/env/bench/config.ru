# The ONE Rack app for the whole dojo. Every server (fork, prefork, thread, fiber)
# serves this same app — readers feel the orthogonality of "app" vs "server".
#
# Endpoints chosen to expose each concurrency model's behaviour under the bench:
#   /        — trivial, fast (throughput baseline)
#   /hold    — sleeps a long time (the slow-client / C10K test: holds a worker/fiber)
#   /io      — sleeps briefly (I/O-bound: releases the GVL, threads & fibers shine)
#   /cpu     — burns CPU (CPU-bound: GVL-pinned, fibers DON'T help — the Ch15 lesson)
require "rack"

def fib(n) = n < 2 ? n : fib(n - 1) + fib(n - 2)

app = lambda do |env|
  case env["PATH_INFO"]
  when "/hold" then sleep 60;  [200, { "content-type" => "text/plain" }, ["held\n"]]
  when "/io"   then sleep 0.05; [200, { "content-type" => "text/plain" }, ["io\n"]]
  when "/cpu"  then fib(30);   [200, { "content-type" => "text/plain" }, ["cpu\n"]]
  else [200, { "content-type" => "text/plain" }, ["hello from rack\n"]]
  end
end

run app
