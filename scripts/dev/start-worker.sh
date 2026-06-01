#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_DIR/api"

export FLASK_APP=app.py
export DATABASE_URL="postgresql://postgres:***@localhost:5432/dify"
export REDIS_URL="redis://:difyai123456@localhost:6379/0"
export CELERY_BROKER_URL="$REDIS_URL"
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH="$PROJECT_DIR/storage"

echo "========================================"
echo " Starting hkai-workflow Studio Celery Worker"
echo "========================================"

source .venv/bin/activate 2>/dev/null || true

exec celery -A celery_entrypoint.celery worker \
  -P gevent \
  -c 1 \
  --max-tasks-per-child 50 \
  --loglevel INFO \
  -Q api_token,dataset,dataset_summary,priority_dataset,priority_pipeline,pipeline,mail,ops_trace,app_deletion,plugin,workflow_storage,conversation,workflow,schedule_poller,schedule_executor,triggered_workflow_dispatcher,trigger_refresh_publisher,trigger_refresh_executor,retention,workflow_based_app_execution
