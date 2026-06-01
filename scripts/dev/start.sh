#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  hkai-workflow Studio — Dev Server        ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"

# Step 1: Start infrastructure
echo -e "\n${YELLOW}[1/4] Starting infrastructure...${NC}"
bash "$SCRIPT_DIR/start-infra.sh"

# Step 2: Run migrations
echo -e "\n${YELLOW}[2/4] Running database migrations...${NC}"
cd "$SCRIPT_DIR/../api"
export FLASK_APP=app.py
export DATABASE_URL="postgresql://postgres:***@localhost:5432/dify"
export REDIS_URL="redis://:difyai123456@localhost:6379/0"
source .venv/bin/activate 2>/dev/null || true
flask upgrade-db 2>/dev/null && echo -e "${GREEN}✅ Migrations done${NC}" || echo -e "${YELLOW}⚠️  Migration skipped${NC}"

# Step 3: Start all services in background
echo -e "\n${YELLOW}[3/4] Starting services...${NC}"

cleanup() {
  echo -e "\n${YELLOW}Shutting down...${NC}"
  kill $API_PID 2>/dev/null || true
  kill $WORKER_PID 2>/dev/null || true
  kill $WEB_PID 2>/dev/null || true
  wait
  echo -e "${GREEN}All services stopped.${NC}"
  exit 0
}

trap cleanup SIGINT SIGTERM

# Start API
echo -e "  ${CYAN}▶ API:${NC}     http://localhost:5001"
bash "$SCRIPT_DIR/start-api.sh" &
API_PID=$!
sleep 2

# Start Worker
echo -e "  ${CYAN}▶ Worker:${NC}  Celery (background)"
bash "$SCRIPT_DIR/start-worker.sh" &
WORKER_PID=$!
sleep 2

# Start Web
echo -e "  ${CYAN}▶ Web:${NC}     http://localhost:3000"
bash "$SCRIPT_DIR/start-web.sh" &
WEB_PID=$!

echo -e "\n${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  All services running!                    ║${NC}"
echo -e "${GREEN}║                                           ║${NC}"
echo -e "${GREEN}║  Frontend: http://localhost:3000           ║${NC}"
echo -e "${GREEN}║  API:      http://localhost:5001           ║${NC}"
echo -e "${GREEN}║                                           ║${NC}"
echo -e "${GREEN}║  Press Ctrl+C to stop all services        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"

# Wait for any process to exit
wait
