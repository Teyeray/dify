#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_DIR/api"

export FLASK_APP=app.py
export FLASK_DEBUG=1
export DATABASE_URL="postgresql://postgres:***@localhost:5432/dify"
export REDIS_URL="redis://:difyai123456@localhost:6379/0"
export CELERY_BROKER_URL="$REDIS_URL"
export DIFY_BIND_ADDRESS="0.0.0.0"
export DIFY_PORT="${DIFY_PORT:-5001}"
export S3_ENDPOINT=""
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH="$PROJECT_DIR/storage"
export LOG_LEVEL=DEBUG

# Create storage dir
mkdir -p "$PROJECT_DIR/storage"

echo "========================================"
echo " Starting hkai-workflow Studio API"
echo " Address: http://$DIFY_BIND_ADDRESS:$DIFY_PORT"
echo "========================================"

source .venv/bin/activate 2>/dev/null || true

# Use python -m app for dev mode (hot-reload friendly)
exec python -m app
