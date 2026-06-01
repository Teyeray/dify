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
echo -e "${CYAN}║  hkai-workflow Studio — Infrastructure ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

# ---- PostgreSQL ----
echo -e "\n${YELLOW}[1/2] PostgreSQL...${NC}"

# Find postgres binary
POSTGRES_BIN=""
for p in /opt/homebrew/opt/postgresql@15/bin /usr/local/opt/postgresql@15/bin /usr/lib/postgresql/*/bin /usr/bin; do
  if [ -x "$p/psql" ]; then
    POSTGRES_BIN="$p"
    break
  fi
done

if [ -z "$POSTGRES_BIN" ]; then
  echo -e "${RED}❌ PostgreSQL not found. Install: brew install postgresql@15${NC}"
  exit 1
fi

# Start PostgreSQL via brew services
if brew services list 2>/dev/null | grep -qE 'postgresql.*started'; then
  echo -e "${GREEN}✅ PostgreSQL already running${NC}"
else
  echo -e "${YELLOW}Starting PostgreSQL via Homebrew...${NC}"
  brew services start postgresql@15 2>&1 | tail -1
  sleep 3
fi

# Ensure postgres role exists
"$POSTGRES_BIN/psql" -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'" 2>/dev/null | grep -q 1 || "$POSTGRES_BIN/createuser" -s postgres 2>/dev/null || true
# Set password
"$POSTGRES_BIN/psql" -c "ALTER USER postgres PASSWORD 'difyai123456';" 2>/dev/null || true
# Ensure dify database exists
"$POSTGRES_BIN/psql" -tAc "SELECT 1 FROM pg_database WHERE datname='dify'" 2>/dev/null | grep -q 1 || "$POSTGRES_BIN/createdb" dify 2>/dev/null || true

# Verify connection
if PGPASSWORD=difyai123456 "$POSTGRES_BIN/psql" -U postgres -d dify -h localhost -c "SELECT 1" > /dev/null 2>&1; then
  echo -e "${GREEN}✅ PostgreSQL ready (postgres:***@localhost:5432/dify)${NC}"
else
  echo -e "${RED}❌ PostgreSQL connection failed${NC}"
  exit 1
fi

# ---- Redis ----
echo -e "\n${YELLOW}[2/2] Redis...${NC}"

if brew services list 2>/dev/null | grep -qE 'redis.*started'; then
  echo -e "${GREEN}✅ Redis already running${NC}"
else
  echo -e "${YELLOW}Starting Redis via Homebrew...${NC}"
  brew services start redis 2>&1 | tail -1
  sleep 2
fi

# Verify
if redis-cli ping 2>/dev/null | grep -q PONG; then
  echo -e "${GREEN}✅ Redis ready (localhost:6379)${NC}"
else
  echo -e "${RED}❌ Redis connection failed${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Infrastructure is ready!             ║${NC}"
echo -e "${GREEN}║  PostgreSQL: localhost:5432            ║${NC}"
echo -e "${GREEN}║  Redis:      localhost:6379            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
