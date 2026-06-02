#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_DIR/web"

PORT="${HKAI_WEB_PORT:-3000}"

echo "========================================"
echo " hkai-workflow Studio Web"
echo " http://localhost:$PORT"
echo "========================================"

exec npx next dev --port "$PORT"
