#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_DIR/api"

PYTHON_BIN="${HKAI_PYTHON:-}"
if [ -z "$PYTHON_BIN" ]; then
  for p in ~/miniforge3/envs/dify/bin/python; do
    if [ -x "$p" ]; then PYTHON_BIN="$p"; break; fi
  done
fi

export FLASK_APP=app.py
export DB_HOST=localhost
export DB_PORT=5432
export DB_USERNAME=postgres
export DB_PASSWORD=difyai...port DB_DATABASE=dify
export REDIS_URL="redis://localhost:6379/0"
export CELERY_BROKER_URL="$REDIS_URL"
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH="$PROJECT_DIR/storage"

echo "========================================"
echo " hkai-workflow Studio Celery Worker"
echo "========================================"

exec "$PYTHON_BIN" -m celery -A celery_entrypoint.celery worker \
  -P gevent -c 1 \
  --max-tasks-per-child 50 \
  --loglevel INFO \
  -Q api_token,dataset,dataset_summary,priority_dataset,priority_pipeline,pipeline,mail,ops_trace,app_deletion,plugin,workflow_storage,conversation,workflow,schedule_poller,schedule_executor,triggered_workflow_dispatcher,trigger_refresh_publisher,trigger_refresh_executor,retention,workflow_based_app_execution
