#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  hkai-workflow Studio — Dev Server        ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"

# Step 1: Start infrastructure (PostgreSQL + Redis via Homebrew)
echo -e "\n${YELLOW}[1/4] Starting infrastructure...${NC}"
bash "$SCRIPT_DIR/start-infra.sh"

# Step 2: Run migrations
echo -e "\n${YELLOW}[2/4] Running database migrations...${NC}"

PYTHON_BIN="${HKAI_PYTHON:-}"
if [ -z "$PYTHON_BIN" ]; then
  for p in ~/miniforge3/envs/dify/bin/python; do
    if [ -x "$p" ]; then PYTHON_BIN="$p"; break; fi
  done
fi

cd "$PROJECT_DIR/api"
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

"$PYTHON_BIN" -m flask upgrade-db 2>&1 | tail -5
echo -e "${GREEN}✅ Migrations done${NC}"

# Step 3: Start all services
echo -e "\n${YELLOW}[3/4] Starting services...${NC}"

cleanup() {
  echo -e "\n${YELLOW}Shutting down...${NC}"
  kill $API_PID 2>/dev/null || true
  kill $WORKER_PID 2>/dev/null || true
  kill $WEB_PID 2>/dev/null || true
  wait 2>/dev/null
  echo -e "${GREEN}All services stopped.${NC}"
  exit 0
}
trap cleanup SIGINT SIGTERM

mkdir -p "$PROJECT_DIR/storage"

# Start API
echo -e "  ${CYAN}▶ API:${NC}     http://localhost:${HKAI_API_PORT:-5001}"
bash "$SCRIPT_DIR/start-api.sh" &
API_PID=$!
sleep 3

# Start Worker (optional, comment out if not needed)
# echo -e "  ${CYAN}▶ Worker:${NC}  Celery (background)"
# bash "$SCRIPT_DIR/start-worker.sh" &
# WORKER_PID=$!

# Start Web
WEB_PORT="${HKAI_WEB_PORT:-3000}"
echo -e "  ${CYAN}▶ Web:${NC}     http://localhost:$WEB_PORT"
bash "$SCRIPT_DIR/start-web.sh" &
WEB_PID=$!

echo -e "\n${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  All services running!                    ║${NC}"
echo -e "${GREEN}║                                           ║${NC}"
echo -e "${GREEN}║  Frontend: http://localhost:$WEB_PORT      ║${NC}"
echo -e "${GREEN}║  API:      http://localhost:${HKAI_API_PORT:-5001}          ║${NC}"
echo -e "${GREEN}║                                           ║${NC}"
echo -e "${GREEN}║  Press Ctrl+C to stop all services        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"

wait
