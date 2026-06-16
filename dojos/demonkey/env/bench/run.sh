#!/usr/bin/env bash
# Memory benchmark harness for demonkey. Runs the learner's server inside a
# cgroup-memory-limited container and HOLDS a wave of idle connections against it,
# sampling peak RSS and watching for the OOM killer. The whole point is the
# contrast:
#
#   fork-per-connection  -> one process per connection; RSS climbs with load
#                           until the container blows past its memory budget and
#                           the kernel OOM-kills it (exit 137 / OOMKilled=true).
#   preforking N workers -> a FIXED pool (CoW-shared); RSS is flat regardless of
#                           how many connections pile up, so it survives the same
#                           load with memory to spare.
#
# This is NOT C10K. The metric is PEAK RSS + whether it got OOM-killed, not the
# max concurrent connections. Connection counts stay modest and demo-friendly.
#
#   run.sh <server_file> [held_count] [mem]
#   e.g.  run.sh curriculum/reference/fork_echo.rb 600 128m
#         run.sh curriculum/reference/prefork.rb   600 128m
#
# Run from the learner's project dir (results land in ./.demonkey/).
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BENCH="$ROOT/env/bench"
IMAGE="demonkey-target"
NAME="demonkey-bench-target"

# Defaults tuned empirically on ruby:4.0 (arm64): fork-per-connection costs ~1.2MiB
# of RSS per held connection, so a 192m budget lets it survive ~75 connections and
# OOM-kills it by ~150 — a few seconds, demo-friendly. Preforking (4 workers) holds
# the SAME 300 connections at a flat ~9MiB and survives. Override per server if you
# retune for a different host.
SERVER="${1:-}"; HELD="${2:-300}"; MEM="${3:-192m}"; CPUS="${4:-0}"
# CPUS is a cgroup cpuset spec: "0" = pin to one core (nproc=1, the honest default),
# "0-1" = two cores, etc. Memory and CPU are both hard cgroup caps on the container.
[[ -z "$SERVER" ]] && { echo "usage: run.sh <server_file> [held_count] [mem] [cpus]   # e.g. server.rb 300 192m 0" >&2; exit 2; }

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not installed — cannot run the cage." >&2; exit 2; }
command -v ruby >/dev/null 2>&1   || { echo "ERROR: ruby not installed — needed for the holder load generator." >&2; exit 2; }
[[ -f "$SERVER" ]] || { echo "ERROR: server file not found: $SERVER (run from your project dir)" >&2; exit 2; }

# The reference echo servers (Steps 1/4/5/6) speak raw TCP; the Rack servers
# (Steps 2/7) speak HTTP. The holder must hold the right kind of connection.
# Default to tcp (the fork-vs-prefork demo lives on the echo servers); override
# with KIND=http for the HTTP servers.
KIND="${KIND:-tcp}"
HOLD="${HOLD:-25}"   # seconds to hold the wave (long enough to sample peak RSS)
MODE="$("$ROOT/bin/dojo.sh" mode 2>/dev/null || echo unknown)"
server_base="$(basename "$SERVER")"
server_dir="$(cd "$(dirname "$SERVER")" && pwd)"

PORT=4000

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- the holder (plain Ruby, runs on the host) ------------------------------
# The cage publishes its port (-p), so the holder runs right here on the host and
# dials 127.0.0.1:$PORT. It's stdlib Ruby — no build step, no Go.
hold_conns() { ruby "$BENCH/holder.rb" -addr "127.0.0.1:$PORT" "$@"; }

# --- ensure image -----------------------------------------------------------
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> building $IMAGE (first run only)…"
  docker build -t "$IMAGE" -f "$BENCH/Dockerfile.target" "$BENCH" || { echo "image build failed" >&2; exit 2; }
fi

# --- ramp of connection counts so the memory CURVE is visible ----------------
# We hold connections CUMULATIVELY: open a batch, snapshot RSS, then open MORE on
# top (the earlier ones stay held), snapshot again, … up to the top rung. So the
# connections accumulate exactly the way real load does, and the RSS readings draw
# fork's climb (more processes => more memory) vs preforking's flat line (fixed
# pool, memory independent of connection count). The top rung is what decides
# survival; caller's HELD is always the top rung.
# Rungs are fractions of the top count so the climb scales with whatever HELD is.
RAMP="$(( HELD / 4 )) $(( HELD / 2 )) $(( HELD * 3 / 4 )) $HELD"
# de-dup + sort the rungs, drop zero/duplicate/over-top rungs
RAMP="$(printf '%s\n' $RAMP | awk -v h="$HELD" '$0>0 && $0<=h && !seen[$0]++' | sort -n | tr '\n' ' ')"

# --- start the cage ---------------------------------------------------------
cleanup
echo "==> starting cage: cpuset-cpus=$CPUS (cgroup CPU) · memory=$MEM / --memory-swap=$MEM (cgroup mem) (held top rung=$HELD, kind=$KIND)"
# Resource caps only — memory + CPU. NOTE: no --rm, so an OOM-killed container
# survives as "exited" long enough for the post-mortem `docker inspect`; the EXIT
# trap removes it. --memory-swap MUST equal --memory, or the kernel swaps instead
# of OOM-killing and the demo's whole point (the kill) never happens.
docker run -d --name "$NAME" \
  --cpuset-cpus="$CPUS" --memory="$MEM" --memory-swap="$MEM" \
  --ulimit nofile=65535:65535 --sysctl net.core.somaxconn=4096 \
  -e HOST=0.0.0.0 -e PORT="$PORT" -p "$PORT:$PORT" \
  -v "$server_dir:/app/workspace:ro" \
  "$IMAGE" ruby "/app/workspace/$server_base" >/dev/null || { echo "container failed to start" >&2; exit 2; }

# --- wait until it accepts --------------------------------------------------
ready=0
for _ in $(seq 1 30); do
  if nc -z 127.0.0.1 "$PORT" >/dev/null 2>&1; then ready=1; break; fi
  if ! docker ps -q -f name="$NAME" | grep -q .; then break; fi  # died early
  sleep 0.5
done
if [[ "$ready" -ne 1 ]]; then
  echo "server never came up on :$PORT — logs:" >&2
  docker logs "$NAME" 2>&1 | tail -20 >&2
  oom="$(docker inspect "$NAME" --format '{{.State.OOMKilled}}' 2>/dev/null || echo unknown)"
  echo "PDOJO_RESULT,$server_base,$MEM,0,0,startup-fail"
  exit 0
fi

# --- background peak-RSS sampler --------------------------------------------
# Sample fast (every 0.25s) so a quick OOM still gets a reading or two before the
# container disappears — otherwise peak_rss reads 0 on servers that blow instantly.
RSSFILE="$(mktemp)"
( while docker ps -q -f name="$NAME" | grep -q .; do
    mu="$(docker stats --no-stream --format '{{.MemUsage}}' "$NAME" 2>/dev/null | awk '{print $1}')"
    # normalise to MiB (handles MiB/GiB/KiB/B)
    val="$(printf '%s' "$mu" | sed -E 's/([0-9.]+).*/\1/')"
    unit="$(printf '%s' "$mu" | sed -E 's/[0-9.]+//')"
    case "$unit" in GiB) val="$(echo "$val*1024" | bc 2>/dev/null)";; KiB) val="$(echo "$val/1024" | bc -l 2>/dev/null)";; esac
    [[ -n "$val" ]] && printf '%s\n' "$val" >> "$RSSFILE"
    sleep 0.25
  done ) &
SAMPLER=$!
disown "$SAMPLER" 2>/dev/null || true   # keep job-control "Terminated" noise out of output

# --- hold connections CUMULATIVELY, snapshotting RSS as the wave grows -------
# For each rung we open only the DELTA of new connections and hold them for the
# whole remaining window in a background holder; earlier holders keep their
# connections open, so the live total climbs 100 -> 300 -> HELD. After each batch
# settles we snapshot the cgroup's peak RSS. fork's curve climbs (a process per
# connection); preforking's stays flat (a fixed pool).
established=0
reason="none"
echo "==> holding connections cumulatively (rungs: $RAMP) on 127.0.0.1:$PORT …"
oom_during=false
prev=0
HOUTS=()
total_window=$(( HOLD + 4 ))
for rung in $RAMP; do
  if ! docker ps -q -f name="$NAME" | grep -q .; then
    echo "    container died before rung=$rung (likely OOM) — stopping ramp"
    oom_during=true
    break
  fi
  delta=$(( rung - prev )); prev="$rung"
  [[ "$delta" -le 0 ]] && continue
  # Background holder for this batch; holds for the rest of the window so the
  # connections accumulate. Its output goes to a per-batch temp file we read after.
  hout="$(mktemp)"; HOUTS+=("$hout")
  ( hold_conns -n "$delta" -hold "${total_window}s" -kind "$KIND" >"$hout" 2>&1 ) &
  hp=$!; disown "$hp" 2>/dev/null || true
  # Let this batch establish + settle, then snapshot.
  sleep 4
  rss_now="$(awk 'BEGIN{m=0} {v=$1+0; if(v>m)m=v} END{printf "%.0f", m}' "$RSSFILE" 2>/dev/null)"; rss_now="${rss_now:-0}"
  alive="yes"; docker ps -q -f name="$NAME" | grep -q . || { alive="no"; oom_during=true; }
  printf '    held~%-5s rss_peak_so_far=%sMiB container=%s\n' "$rung" "$rss_now" "$alive"
  established="$rung"
  [[ "$alive" == "no" ]] && break
done

# Dominant failure reason across the batch holders (client-side reset/refused/etc).
for f in "${HOUTS[@]:-}"; do
  [[ -f "$f" ]] || continue
  rsn="$(sed -n 's/.*first_error=\([^ ]*\).*/\1/p' "$f" | tail -1)"
  [[ -n "$rsn" && "$rsn" != "none" ]] && reason="$rsn"
  rm -f "$f"
done

# Give the OOM killer / kernel a beat to act, then sample once more.
sleep 2

# --- stop sampler, read peak RSS --------------------------------------------
kill "$SAMPLER" >/dev/null 2>&1 || true
peak_rss="$(awk 'BEGIN{m=0} {v=$1+0; if(v>m)m=v} END{printf "%.0f", m}' "$RSSFILE" 2>/dev/null)"; peak_rss="${peak_rss:-0}"
rm -f "$RSSFILE"

# --- OOM + verdict ----------------------------------------------------------
oom="$(docker inspect "$NAME" --format '{{.State.OOMKilled}}' 2>/dev/null | tr -d '[:space:]')"; oom="${oom:-false}"
exitcode="$(docker inspect "$NAME" --format '{{.State.ExitCode}}' 2>/dev/null | tr -d '[:space:]')"
[[ "$exitcode" == "137" ]] && oom="true"   # 137 = SIGKILL, the OOM killer's signature
[[ "$oom_during" == "true" ]] && oom="true"
[[ "$reason" == "client-ephemeral-exhausted" ]] && echo "   WARNING: generator hit ephemeral-port exhaustion — this measures the CLIENT, not the server. Lower the held count or rerun."

if [[ "$oom" == "true" ]]; then verdict="OOM-KILLED"; else verdict="SURVIVED"; fi

echo "----------------------------------------------------------------"
printf "  server=%s mem_budget=%s held=%d peak_rss=%sMiB oom=%s => %s\n" \
  "$server_base" "$MEM" "$established" "$peak_rss" "$oom" "$verdict"
if [[ "$oom" == "true" ]]; then
  echo "  VERDICT: a process per connection means memory grows with load — it blew the $MEM budget and got OOM-killed."
else
  echo "  VERDICT: a fixed pool of workers stays flat — peak RSS ${peak_rss}MiB held well under the $MEM budget."
fi
echo "----------------------------------------------------------------"

# machine-readable row for the post-bench hook:
#   PDOJO_RESULT,<server>,<budget>,<held>,<peak_rss_mb>,<oom>
echo "PDOJO_RESULT,$server_base,$MEM,$established,$peak_rss,$oom"
