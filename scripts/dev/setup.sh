#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  hkai-workflow Studio — Setup         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

# Find conda/miniforge Python 3.12
PYTHON_BIN=""
for p in ~/miniforge3/envs/dify/bin/python ~/.local/share/uv/python/cpython-3.12*/bin/python; do
  if [ -x "$p" ]; then
    PYTHON_BIN="$p"
    break
  fi
done

if [ -z "$PYTHON_BIN" ]; then
  echo -e "${YELLOW}No Python 3.12 found. Run setup first or use conda:${NC}"
  echo "  conda create -n dify python=3.12 -c conda-forge"
  echo "  conda activate dify && pip install -e ./dify-agent -e ./api"
  exit 1
fi

PIP="$($PYTHON_BIN -m pip)"

# ---- API Backend ----
echo -e "\n${YELLOW}[1/4] Python dependencies...${NC}"

# Install dify-agent first
if [ -d "$PROJECT_DIR/dify-agent" ]; then
  echo -e "${YELLOW}  Installing dify-agent...${NC}"
  $PIP install -e "$PROJECT_DIR/dify-agent" 2>&1 | tail -1
fi

# Install API
echo -e "${YELLOW}  Installing API dependencies...${NC}"
$PIP install -e "$PROJECT_DIR/api" 2>&1 | tail -1

# ---- Frontend ----
echo -e "\n${YELLOW}[2/4] Frontend dependencies...${NC}"
if ! command -v pnpm &> /dev/null; then
  echo -e "${YELLOW}  Installing pnpm...${NC}"
  npm install -g pnpm 2>&1 | tail -1
fi

cd "$PROJECT_DIR"
pnpm install 2>&1 | tail -3

# ---- Database Migration ----
echo -e "\n${YELLOW}[3/4] Database migration...${NC}"
cd "$PROJECT_DIR/api"

export FLASK_APP=app.py
export DB_HOST=localhost
export DB_PORT=5432
export DB_USERNAME=postgres
export DB_PASSWORD=difyai123456
export DB_DATABASE=dify
export REDIS_URL="redis://localhost:6379/0"
export CELERY_BROKER_URL="$REDIS_URL"
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH="$PROJECT_DIR/storage"

$PYTHON_BIN -m flask upgrade-db 2>&1 | tail -3

# ---- Storage ----
echo -e "\n${YELLOW}[4/4] Creating storage directory...${NC}"
mkdir -p "$PROJECT_DIR/storage"

echo -e "\n${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Setup complete!                      ║${NC}"
echo -e "${GREEN}║                                        ║${NC}"
echo -e "${GREEN}║  Run ./scripts/dev/start.sh to start   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
