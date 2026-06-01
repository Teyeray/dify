#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_DIR/api"

# Find Python 3.12
PYTHON_BIN="${HKAI_PYTHON:-}"
if [ -z "$PYTHON_BIN" ]; then
  for p in ~/miniforge3/envs/dify/bin/python; do
    if [ -x "$p" ]; then PYTHON_BIN="$p"; break; fi
  done
fi
if [ -z "$PYTHON_BIN" ]; then
  echo "No Python 3.12 found. Activate your env and set HKAI_PYTHON, or edit this script."
  exit 1
fi

export FLASK_APP=app.py
export DB_HOST=localhost
export DB_PORT=5432
export DB_USERNAME=postgres
export DB_PASSWORD=***
export DB_DATABASE=dify
export REDIS_URL="redis://localhost:6379/0"
export CELERY_BROKER_URL="$REDIS_URL"
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH="$PROJECT_DIR/storage"
export DIFY_BIND_ADDRESS="0.0.0.0"
export DIFY_PORT="${HKAI_API_PORT:-5001}"

mkdir -p "$PROJECT_DIR/storage"

echo "========================================"
echo " hkai-workflow Studio API"
echo " http://$DIFY_BIND_ADDRESS:$DIFY_PORT"
echo "========================================"

exec "$PYTHON_BIN" -m app
