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

mkdir -p "$PROJECT_DIR/storage"

echo "========================================"
echo " hkai-workflow Studio API"
echo " http://0.0.0.0:5001"
echo "========================================"

exec "$PYTHON_BIN" -m app
