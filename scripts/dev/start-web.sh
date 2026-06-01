#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_DIR/web"

export NEXT_PUBLIC_DEPLOY_ENV=PRODUCTION
export NEXT_PUBLIC_EDITION=SELF_HOSTED
export NEXT_PUBLIC_API_PREFIX="${HKAI_API_URL:-http://localhost:5001}/console/api"
export NEXT_PUBLIC_PUBLIC_API_PREFIX="${HKAI_API_URL:-http://localhost:5001}/api"
export NEXT_PUBLIC_SOCKET_URL=
export NEXT_TELEMETRY_DISABLED=1

PORT="${HKAI_WEB_PORT:-3000}"

echo "========================================"
echo " hkai-workflow Studio Web"
echo " http://localhost:$PORT"
echo "========================================"

exec npx next dev --port "$PORT"
