#!/usr/bin/env bash
# Constrained benchmark harness. Runs the learner's server inside a cgroup-limited
# container and stresses it, then prints a result row (and a C10K_RESULT marker the
# post-bench hook captures).
#
#   run.sh <server_file> <bronze|silver|gold> [tcp|http]
#   e.g.  run.sh workspace/falcon_like.rb silver http
#
# Run from the learner's project dir (where ./workspace and ./docs live).
set -uo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BENCH="$ROOT/env/bench"
IMAGE="c10k-target"
NAME="c10k-bench-target"

SERVER="${1:-}"; TIER="${2:-bronze}"; KIND="${3:-http}"
[[ -z "$SERVER" ]] && { echo "usage: run.sh <server_file> <bronze|silver|gold> [tcp|http]" >&2; exit 2; }

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not installed — cannot run the cage." >&2; exit 2; }
command -v go >/dev/null 2>&1     || { echo "ERROR: go not installed — needed for the holder load generator." >&2; exit 2; }
[[ -f "$SERVER" ]] || { echo "ERROR: server file not found: $SERVER (run from your project dir)" >&2; exit 2; }

case "$TIER" in
  bronze) TARGET=1000;  MEM=256m ;;
  silver) TARGET=10000; MEM=512m ;;   # async needs ~350MB for 10k (~35KB/conn); 256m tops ~9.5k
  gold)   TARGET=50000; MEM=512m ;;
  *) echo "unknown tier: $TIER" >&2; exit 2 ;;
esac
# Optional overrides for experiments (e.g. MEM_OVERRIDE=512m, TARGET_OVERRIDE=8000).
[[ -n "${MEM_OVERRIDE:-}" ]] && MEM="$MEM_OVERRIDE"
[[ -n "${TARGET_OVERRIDE:-}" ]] && TARGET="$TARGET_OVERRIDE"
HOLD=30
MODE="$("$ROOT/bin/dojo.sh" mode 2>/dev/null || echo unknown)"
server_base="$(basename "$SERVER")"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- ensure image -----------------------------------------------------------
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> building $IMAGE (first run only)…"
  docker build -t "$IMAGE" -f "$BENCH/Dockerfile.target" "$BENCH" || { echo "image build failed" >&2; exit 2; }
fi

# --- start the cage ---------------------------------------------------------
cleanup
echo "==> starting cage: --cpuset-cpus=0 (1 real core, nproc=1) --memory=$MEM --memory-swap=$MEM (tier=$TIER target=$TARGET)"
# NOTE: no --rm. An OOM-killed container must survive as "exited" long enough for
# the post-mortem `docker inspect` below; the EXIT trap removes it explicitly.
# --cpuset-cpus=0 pins to ONE physical core via the cgroup cpuset controller, so the
# container honestly sees nproc=1 (unlike --cpus=1, which throttles quota but still
# reports all host cores). This makes the GVL/parallelism lessons land truthfully.
docker run -d --name "$NAME" \
  --cpuset-cpus=0 --memory="$MEM" --memory-swap="$MEM" \
  --ulimit nofile=65535:65535 --sysctl net.core.somaxconn=4096 \
  -e HOST=0.0.0.0 -e PORT=4000 -p 4000:4000 \
  -v "$PWD/workspace:/app/workspace:ro" \
  "$IMAGE" ruby "/app/workspace/$server_base" >/dev/null || { echo "container failed to start" >&2; exit 2; }

# --- wait until it accepts --------------------------------------------------
ready=0
for _ in $(seq 1 30); do
  if nc -z 127.0.0.1 4000 >/dev/null 2>&1; then ready=1; break; fi
  if ! docker ps -q -f name="$NAME" | grep -q .; then break; fi  # died early
  sleep 0.5
done
if [[ "$ready" -ne 1 ]]; then
  echo "server never came up on :4000 — logs:" >&2
  docker logs "$NAME" 2>&1 | tail -20 >&2
  oom="$(docker inspect "$NAME" --format '{{.State.OOMKilled}}' 2>/dev/null || echo unknown)"
  echo "C10K_RESULT,$server_base,$MODE,$MEM,0,startup-fail,0,na,na,0,$oom"
  exit 0
fi

# --- sample peak RSS in the background --------------------------------------
RSSFILE="$(mktemp)"
( while docker ps -q -f name="$NAME" | grep -q .; do
    mu="$(docker stats --no-stream --format '{{.MemUsage}}' "$NAME" 2>/dev/null | awk '{print $1}')"
    # normalise to MiB (handles MiB/GiB/KiB/B)
    val="$(printf '%s' "$mu" | sed -E 's/([0-9.]+).*/\1/')"
    unit="$(printf '%s' "$mu" | sed -E 's/[0-9.]+//')"
    case "$unit" in GiB) val="$(echo "$val*1024" | bc 2>/dev/null)";; KiB) val="$(echo "$val/1024" | bc -l 2>/dev/null)";; esac
    printf '%s\n' "$val" >> "$RSSFILE"
    sleep 1
  done ) &
SAMPLER=$!
disown "$SAMPLER" 2>/dev/null || true   # keep job-control "Terminated" noise out of output

# --- concurrency: hold N connections ----------------------------------------
# On macOS the host→container published-port proxy ACCEPTS connections itself,
# masking a server's real backlog/refusal ceiling. For Silver/Gold we bypass it:
# run the holder in a tiny sibling container sharing the target's network namespace
# (--network container:NAME), so 127.0.0.1:4000 hits the server directly.
echo "==> holding $TARGET connections (kind=$KIND, hold=${HOLD}s)…"
if [[ "$TIER" == "bronze" ]]; then
  holder_out="$(cd "$BENCH" && go run holder.go -addr 127.0.0.1:4000 -n "$TARGET" -hold "${HOLD}s" -kind "$KIND" 2>&1)"
else
  darch="$(docker info --format '{{.Architecture}}' 2>/dev/null)"
  case "$darch" in aarch64|arm64) goarch=arm64 ;; x86_64|amd64) goarch=amd64 ;; *) goarch=arm64 ;; esac
  hbin="$BENCH/.holder_${goarch}"
  echo "    (sibling-netns mode, goarch=$goarch — bypassing the host port proxy)"
  if (cd "$BENCH" && GOOS=linux GOARCH="$goarch" CGO_ENABLED=0 go build -o "$hbin" holder.go); then
    holder_out="$(docker run --rm --network "container:$NAME" -v "$hbin:/holder:ro" alpine:latest \
      /holder -addr 127.0.0.1:4000 -n "$TARGET" -hold "${HOLD}s" -kind "$KIND" 2>&1)"
  else
    echo "    holder cross-compile failed — falling back to host (proxy may mask the ceiling)"
    holder_out="$(cd "$BENCH" && go run holder.go -addr 127.0.0.1:4000 -n "$TARGET" -hold "${HOLD}s" -kind "$KIND" 2>&1)"
  fi
fi
echo "$holder_out"
established="$(printf '%s' "$holder_out" | sed -n 's/.*established=\([0-9]*\).*/\1/p' | tail -1)"; established="${established:-0}"
reason="$(printf '%s' "$holder_out" | sed -n 's/.*first_error=\([^ ]*\).*/\1/p' | tail -1)"; reason="${reason:-none}"

# --- throughput + latency (HTTP only, via ApacheBench — ships with macOS/Linux) ---
# ab is closed-loop (no rate cap), so it can't dodge coordinated omission the way a
# rate-limited tool would — but it's the ubiquitous default and fine for the dojo.
# (holder.go still owns the held-connection / C10K capacity metric; ab can't hold idle.)
req_s="na"; p50="na"; p99="na"
if [[ "$KIND" == "http" ]]; then
  AB="$(command -v ab 2>/dev/null || echo /usr/sbin/ab)"
  if [[ -x "$AB" ]]; then
    echo "==> throughput (ab -c 50 -k, ~10s) on /…"
    tp="$("$AB" -t 10 -n 200000 -c 50 -k "http://127.0.0.1:4000/" 2>/dev/null || true)"
    req_s="$(printf '%s' "$tp" | sed -n 's/^Requests per second:[[:space:]]*\([0-9.]*\).*/\1/p' | head -1)"; req_s="${req_s:-na}"
    echo "    Requests/sec: $req_s"
    echo "==> latency (ab -c 200, ~10s) on /io…"
    lt="$("$AB" -t 10 -n 200000 -c 200 "http://127.0.0.1:4000/io" 2>/dev/null || true)"
    p50="$(printf '%s' "$lt" | awk '/^[[:space:]]*50%/{print $2; exit}')"; p50="${p50:-na}"
    p99="$(printf '%s' "$lt" | awk '/^[[:space:]]*99%/{print $2; exit}')"; p99="${p99:-na}"
    echo "    p50=${p50}ms p99=${p99}ms"
  else
    echo "   (ab not found — install Apache httpd tools, or it's at /usr/sbin/ab on macOS)"
  fi
fi

# --- stop sampler, read peak RSS --------------------------------------------
kill "$SAMPLER" >/dev/null 2>&1 || true
peak_rss="$(sort -nr "$RSSFILE" 2>/dev/null | head -1)"; peak_rss="${peak_rss:-0}"
rm -f "$RSSFILE"

# --- OOM + verdict ----------------------------------------------------------
oom="$(docker inspect "$NAME" --format '{{.State.OOMKilled}}' 2>/dev/null | tr -d '[:space:]')"; oom="${oom:-false}"
exitcode="$(docker inspect "$NAME" --format '{{.State.ExitCode}}' 2>/dev/null | tr -d '[:space:]')"
[[ "$exitcode" == "137" ]] && oom="true"   # 137 = SIGKILL, the OOM killer's signature
[[ "$reason" == "client-ephemeral-exhausted" ]] && echo "   WARNING: generator hit ephemeral-port exhaustion — this measures the CLIENT, not the server. Result disqualified; rerun with sibling-container networking for high tiers."

verdict="FAIL"
# Allow a 1% margin — C10K is "~10k", and a stray reset during the connection
# storm shouldn't flip a clean run. OOM is always a hard fail.
if [[ $(( established * 100 )) -ge $(( TARGET * 99 )) && "$oom" != "true" ]]; then
  if [[ "$TIER" == "silver" && "$KIND" == "http" && "$p99" != "na" ]]; then
    awk "BEGIN{exit !($p99 < 100)}" && verdict="PASS" || verdict="FAIL(p99>=100ms)"
  else
    verdict="PASS"
  fi
fi

echo "----------------------------------------------------------------"
printf "  server=%s tier=%s established=%d/%d oom=%s req_s=%s p99=%s peak_rss=%sMiB => %s\n" \
  "$server_base" "$TIER" "$established" "$TARGET" "$oom" "$req_s" "$p99" "$peak_rss" "$verdict"
echo "----------------------------------------------------------------"

# machine-readable row for the post-bench hook
echo "C10K_RESULT,$server_base,$MODE,$MEM,$established,$reason,$req_s,$p50,$p99,$peak_rss,$oom"
