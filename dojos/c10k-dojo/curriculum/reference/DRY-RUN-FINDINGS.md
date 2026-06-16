# Dry-run findings (2026-06-01) — Steps 1, 2, 4 on the real harness

Ran the canonical echo / rack / fork servers through `env/bench/run.sh`. Cage: **`--cpuset-cpus=0`
(one real core, `nproc=1`) + `--memory=256m --memory-swap=256m`**. Load tools: **`ab` (ApacheBench,
ships with macOS/Linux)** for throughput + latency, **holder.go** for held-connection capacity.

## Baseline numbers (bronze = 1,000 held, 256 MB, 1 core)

| Server | held | OOM | req/s (`/`, ab -c50 -k) | p99 (`/io`, ab -c200) | RSS | verdict |
|---|---|---|---|---|---|---|
| `echo.rb` (single-thread) | 1000/1000 | no | — | — | 7.4 MiB | **PASS** |
| `fork_echo.rb` (fork/conn) | 1000 then **killed** | **yes (137)** | — | — | — | **FAIL** |
| `rack_server.rb` (single-thread HTTP) | 996/1000 | no | **5903** | **9905 ms** | 9.2 MiB | PASS* |

\*PASS on the connection bar, but the `/io` latency is the real story — see finding #1.

## Finding 1 — idle-hold count does NOT discriminate single-thread from threaded at Bronze
A single-threaded server **parks ~4,096 idle connections in the kernel listen backlog** for almost
nothing (echo held 1,000 at 7.4 MiB). So "hold 1,000 connections" is too easy a bar — everyone
except fork clears it. **What actually exposes single-threaded is *latency under concurrent I/O*:**
`ab -c 200` against `/io` (50 ms each) on the single-thread Rack server gave **p50 ≈ 5 s, p99 ≈ 10 s**
— 200 connections all queue behind serialized work. (`ab` is closed-loop, so it surfaces the full
queueing latency rather than dropping load; that makes the failure dramatic and obvious.)
→ **Curriculum fix:** at Bronze, teach the failure via the `/io` p99 (seconds!), not the held count.
The held-connection wall is a **Silver (10k)** phenomenon — 10k > backlog, so single-thread/thread-
pool get *refused* past ~4k while async holds 10k+ as cheap fibers.

## Finding 0 — the cage now pins to one real core (`nproc=1`), so the old "nproc lies" trap is gone
Switched from `--cpus=1` (quota throttle; container still saw 14 cores) to **`--cpuset-cpus=0`**
(cgroup cpuset → `nproc=1`, `cpuset.cpus.effective=0`). `Etc.nprocessors` now honestly returns 1, so
preforking with a hardcoded N is a deliberate oversubscription *choice*, not a defense against a
lying `nproc`. The GVL lessons (Step 8/9) also land truthfully on one core.

## Finding 2 — fork's wall is real, but it's about *eagerness*, not idle cost
Counterintuitive and great teaching material: fork-per-connection **FAILS Bronze where single-thread
PASSES** — because fork is *too eager*. It spawns a whole process per connection; 1,000 processes
OOM-kill the container (exit 137), while the single-threaded server just parks the same 1,000 idle.
A trivial echo *child* is cheap via copy-on-write, so the wall is the **process count × baseline
RSS**, not per-connection app memory. (With app-sized children dirtying pages, it OOMs far sooner.)
→ **Curriculum fix:** frame Step 4 as "fork trades memory for concurrency — and idle holds are the
worst case for that trade." The OOM at 1,000 is the lesson; don't claim "~300" (that assumed
app-sized children).

## Finding 3 — two harness bugs, fixed
- `--rm` auto-removed OOM-killed containers before the post-mortem `docker inspect`, so OOM
  mis-reported as `false`. Fixed: dropped `--rm` (the EXIT trap removes the container), and added an
  exit-code 137 check.
- The pass threshold flipped to FAIL on a single transient reset during the connection storm. Fixed:
  1% margin (C10K is "~10k", not exact). OOM remains a hard fail.

## Known cosmetic gap
`peak_rss` reads 0 for fork — `docker stats` can't sample reliably under a 1,000-process fork storm.
The `oom=true` flag carries the signal; RSS sampling for fork is best-effort. Low priority.

## Silver (10k) dry-run — Steps 9 & 13 (added 2026-06-01)

| Server | budget | held (true) | p99 `/io` | RSS | verdict |
|---|---|---|---|---|---|
| `puma_like.rb` (pool=16) | 256m | **5,140** | 723 ms | 9.5 MiB | FAIL — backlog cap |
| `falcon_like.rb` (async) | 256m | **9,500** then **OOM** | — | (peak >256) | FAIL — OOM at the edge |
| `falcon_like.rb` (async) | **512m** | **10,000** | **93 ms** | 348 MiB | **PASS — C10K** |

### Finding 4 — the host published-port proxy MASKS the real ceiling (big methodology fix)
First Silver run via `-p 4000:4000` reported puma holding **9,961** — impossible for a 16-worker pool.
On macOS, Docker Desktop's userland port proxy *accepts the connections itself* and buffers them, so
the holder measured the **proxy**, not the server. Fix: for Silver/Gold the holder runs in a **sibling
container sharing the target's netns** (`--network container:NAME`), hitting `127.0.0.1:4000`
directly. True numbers then appeared: puma **5,140** (= 16 workers + 1024 SizedQueue + ~4096 backlog,
exactly), the rest timed out. (`--rm`-style published-port path is fine for Bronze, where OOM/park
outcomes don't depend on the proxy.)

### Finding 5 — the thread-pool ceiling is *structural*, not memory-bound
puma capped at ~5,140 and **more RAM won't move it** — the limit is backlog + queue + worker count.
A held/slow connection occupies a worker (blocked in `read_request`); 16 workers + a bounded queue +
the kernel backlog is the wall. Throwing memory at threads doesn't reach 10k usefully.

### Finding 6 — async scales with memory (~35 KB/conn); C10K needs ~512 MB here, not 256
async got *furthest* but at 256 MB OOM'd right at ~9.5k. With 512 MB it cleanly held **10,000** at
**p99 93 ms, 9,570 req/s, 348 MiB** on one core. So ~35 KB per connection (fiber + protocol-http1
buffers). → **Curriculum/tier fix:** Silver budget is now **512 MB** (256 MB tops async ~9.5k — a
nice "so close" demo, but not a clean pass). The single CPU is irrelevant to capacity: async holds
10k held *and* serves the `ab` load at 93 ms p99 on one core.

### The money chart (one core)
fork OOMs ~1k · thread-pool caps ~5.1k (structural) · **async holds 10k at p99 93 ms.**
C10K is a **per-connection-cost** problem (process → stack → KB-fiber), not a CPU problem.

## Still to dry-run
Gold (≥50k) needs multi-source load (one sibling exhausts ~28k container ephemeral ports) — that's
the "200k out of scope for one box" caveat made concrete. Steps 6/7 (master/USR2) and 15/16 (Ractors)
are behavioral, not capacity — verify functionally, not via the curve.
