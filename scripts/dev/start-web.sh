#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_DIR/web"

export NEXT_PUBLIC_DEPLOY_ENV=PRODUCTION
export NEXT_PUBLIC_EDITION=SELF_HOSTED
export NEXT_PUBLIC_API_PREFIX=http://localhost:5001/console/api
export NEXT_PUBLIC_PUBLIC_API_PREFIX=http://localhost:5001/api
export NEXT_PUBLIC_SOCKET_URL=
export NEXT_PUBLIC_TEXT_GENERATION_TIMEOUT_MS=60000
export NEXT_TELEMETRY_DISABLED=1
export PORT="${WEB_PORT:-3000}"

echo "========================================"
echo " Starting hkai-workflow Studio Web"
echo " Address: http://localhost:$PORT"
echo "========================================"

exec npx next dev --port "$PORT"
