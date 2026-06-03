#!/usr/bin/env bash
# scripts/dev/start-all.sh
# Start all Dify dev services in the background, multiplexing output
# into a single log file with [HH:MM:SS] [service ] prefixes.
#
# Environment variables (all optional — Makefile passes them):
#   PYTHON            Python binary           (default: python)
#   SANDBOX_PORT      Dev sandbox port        (default: 8194)
#   SANDBOX_API_KEY   Dev sandbox API key     (default: dify-sandbox)
#   API_PORT          Flask API port          (default: 5001)
#   WEB_PORT          Next.js port            (default: 3000)
#   LOGS_DIR          Log directory           (default: logs)
#   PID_FILE          PID tracking file       (default: .codeserver.pids)

set -euo pipefail

PYTHON="${PYTHON:-python}"
SANDBOX_PORT="${SANDBOX_PORT:-8194}"
SANDBOX_API_KEY="${SANDBOX_API_KEY:-dify-sandbox}"
API_PORT="${API_PORT:-5001}"
WEB_PORT="${WEB_PORT:-3000}"
LOGS_DIR="${LOGS_DIR:-logs}"
PID_FILE="${PID_FILE:-.codeserver.pids}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

LOG_FILE="$LOGS_DIR/codeserver.log"

mkdir -p "$LOGS_DIR"
: > "$PID_FILE"

# ── helpers ──────────────────────────────────────────────────────────────────

log_header() {
  printf '\n'
  printf '══════════════════════════════════════════════════════\n'
  printf '  Session started : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf '══════════════════════════════════════════════════════\n'
}

# Python-based line prefixer — portable, no gawk/strftime dependency
# Usage: ... 2>&1 | prefix_lines <name>
prefix_lines() {
  local name="$1"
  "$PYTHON" -u -c "
import sys, datetime
name = sys.argv[1]
for line in sys.stdin:
    ts = datetime.datetime.now().strftime('%H:%M:%S')
    sys.stdout.write('[%s] [%-8s] %s' % (ts, name, line))
    sys.stdout.flush()
" "$name"
}

# start_svc <name> <workdir> <cmd> [args...]
# - Starts cmd inside a subshell (for cd), captures its PID via a temp file
# - Pipes all output through prefix_lines and appends to LOG_FILE
# - Killing the stored PID stops the service; the prefixer exits on EOF
start_svc() {
  local name="$1" dir="$2"; shift 2
  local tmp_pid; tmp_pid=$(mktemp)

  printf '[%s] [%-8s] ─── starting ───\n' "$(date +%H:%M:%S)" "$name" >> "$LOG_FILE"

  (
    cd "$dir"
    "$@" &          # start the actual service
    echo $! > "$tmp_pid"
    wait            # keep subshell alive; when service dies, subshell exits → pipe closes
  ) 2>&1 | prefix_lines "$name" >> "$LOG_FILE" &

  # Wait for the inner process to start and write its PID (up to 2 s)
  local i=0
  while [ $i -lt 20 ] && [ ! -s "$tmp_pid" ]; do
    sleep 0.1
    i=$((i + 1))
  done

  local svc_pid; svc_pid=$(cat "$tmp_pid" 2>/dev/null || echo "")
  rm -f "$tmp_pid"

  if [ -n "$svc_pid" ] && kill -0 "$svc_pid" 2>/dev/null; then
    printf '%s\t%s\n' "$name" "$svc_pid" >> "$PID_FILE"
    printf '  ✓ %-10s pid=%-6s\n' "$name" "$svc_pid"
  else
    printf '  ✗ %-10s failed to start — check %s\n' "$name" "$LOG_FILE"
  fi
}

# ── main ─────────────────────────────────────────────────────────────────────

log_header >> "$LOG_FILE"
echo "Starting Dify dev services → $LOG_FILE"
echo ""

# Sandbox: skip if already responding on the port (idempotent)
if curl -sf "http://localhost:${SANDBOX_PORT}/health" >/dev/null 2>&1; then
  existing_pid=$(lsof -ti:"$SANDBOX_PORT" 2>/dev/null | head -1 || echo "?")
  printf '  – %-10s already running on :%s (pid=%s)\n' "sandbox" "$SANDBOX_PORT" "$existing_pid"
  printf '%s\t%s\n' "sandbox" "$existing_pid" >> "$PID_FILE"
else
  start_svc "sandbox" "$ROOT" \
    env SANDBOX_PORT="$SANDBOX_PORT" SANDBOX_API_KEY="$SANDBOX_API_KEY" \
    "$PYTHON" scripts/dev/sandbox-server.py
fi

start_svc "api" "$ROOT/api" \
  "$PYTHON" -m app

start_svc "worker" "$ROOT/api" \
  "$PYTHON" -m celery -A celery_entrypoint.celery worker \
    -P gevent -c 1 --max-tasks-per-child 50 --loglevel INFO \
    -Q api_token,dataset,dataset_summary,priority_dataset,priority_pipeline,pipeline,mail,ops_trace,app_deletion,plugin,workflow_storage,conversation,workflow,schedule_poller,schedule_executor,triggered_workflow_dispatcher,trigger_refresh_publisher,trigger_refresh_executor,retention,workflow_based_app_execution

start_svc "web" "$ROOT/web" \
  env PORT="$WEB_PORT" pnpm dev

echo ""
echo "  Tail logs  →  make codeserver-logs"
echo "  Stop all   →  make codeserver-stop-all"
