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
echo -e "${CYAN}║  hkai-workflow Studio — Setup          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

# ---- API Backend ----
echo -e "\n${YELLOW}[1/4] Setting up Python API backend...${NC}"

cd "$PROJECT_DIR"

# Check if uv is installed
if ! command -v uv &> /dev/null; then
  echo -e "${YELLOW}Installing uv...${NC}"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

cd "$PROJECT_DIR/api"

# Check .venv
if [ ! -d ".venv" ]; then
  echo -e "${YELLOW}Creating Python virtual environment...${NC}"
  uv venv
fi

source .venv/bin/activate

echo -e "${YELLOW}Installing Python dependencies...${NC}"
# Install dify-agent dependency first (local workspace member)
cd "$PROJECT_DIR/dify-agent"
uv sync --frozen --no-dev --no-editable 2>/dev/null || pip install -e .

cd "$PROJECT_DIR/api"
uv sync --frozen --no-dev --no-editable 2>/dev/null || pip install -e ".[dev]"

# --- Database Migration ---
echo -e "\n${YELLOW}[2/4] Running database migrations...${NC}"
cd "$PROJECT_DIR/api"
export FLASK_APP=app.py
export FLASK_DEBUG=1
export DATABASE_URL="postgresql://postgres:difyai123456@localhost:5432/dify"
export REDIS_URL="redis://:difyai123456@localhost:6379/0"

flask upgrade-db 2>/dev/null || echo -e "${YELLOW}⚠️  Migration skipped (DB may not be ready yet, run later via 'flask upgrade-db')${NC}"

# --- CLI + SDK ---
echo -e "\n${YELLOW}[3/4] Setting up CLI...${NC}"
cd "$PROJECT_DIR/cli"
if [ ! -d ".venv" ]; then
  uv venv
fi
source .venv/bin/activate
uv sync --no-dev 2>/dev/null || pip install -e .

# --- Web Frontend ---
echo -e "\n${YELLOW}[4/4] Setting up Web Frontend...${NC}"

# Check if pnpm is installed
if ! command -v pnpm &> /dev/null; then
  echo -e "${YELLOW}Installing pnpm...${NC}"
  npm install -g pnpm
fi

cd "$PROJECT_DIR"
pnpm install --frozen-lockfile 2>/dev/null || pnpm install

echo -e "\n${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Setup complete!                      ║${NC}"
echo -e "${GREEN}║                                        ║${NC}"
echo -e "${GREEN}║  Run ./scripts/dev/start.sh to start   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
