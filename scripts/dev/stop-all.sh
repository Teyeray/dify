#!/usr/bin/env bash
# scripts/dev/stop-all.sh
# Stop all Dify dev services started by start-all.sh.
# Reads PIDs from .codeserver.pids and kills each service.
# Falls back to pattern-based pkill if the PID is stale.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PID_FILE="${PID_FILE:-.codeserver.pids}"
LOGS_DIR="${LOGS_DIR:-logs}"
LOG_FILE="$LOGS_DIR/codeserver.log"

stop_by_pid() {
  local name="$1" pid="$2"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    printf '  ✓ %-10s stopped  (pid=%s)\n' "$name" "$pid"
    return 0
  fi
  return 1
}

kill_pattern_for() {
  case "$1" in
    sandbox) echo "sandbox-server.py" ;;
    api)     echo "python -m app" ;;
    worker)  echo "celery_entrypoint" ;;
    web)     echo "next dev" ;;
    *)       echo "" ;;
  esac
}

stop_by_pattern() {
  local name="$1"
  local pattern; pattern=$(kill_pattern_for "$name")
  [ -z "$pattern" ] && return 1
  if pkill -f "$pattern" 2>/dev/null; then
    printf '  ✓ %-10s stopped  (pattern match)\n' "$name"
    return 0
  fi
  return 1
}

# ── main ─────────────────────────────────────────────────────────────────────

if [ ! -f "$PID_FILE" ]; then
  echo "No PID file found ($PID_FILE) — trying pattern-based stop."
  echo ""
  for name in sandbox api worker web; do
    stop_by_pattern "$name" || printf '  – %-10s not running\n' "$name"
  done
  exit 0
fi

echo "Stopping Dify dev services..."
echo ""

while IFS=$'\t' read -r name pid; do
  [ -z "${name:-}" ] && continue
  stop_by_pid "$name" "$pid" || \
    stop_by_pattern "$name" || \
    printf '  – %-10s not running\n' "$name"
done < "$PID_FILE"

rm -f "$PID_FILE"

if [ -f "$LOG_FILE" ]; then
  printf '\n[%s] [%-8s] ─── session ended ───\n' \
    "$(date +%H:%M:%S)" "stopped" >> "$LOG_FILE"
fi

echo ""
echo "Done.  Log preserved at $LOG_FILE"
