#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  hkai-workflow Studio — Infrastructure ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo -e "${RED}❌ Docker is not running. Please start Docker Desktop first.${NC}"
  exit 1
fi

# --- PostgreSQL ---
if docker ps --format '{{.Names}}' | grep -q '^hkai-postgres$'; then
  echo -e "${GREEN}✅ PostgreSQL already running${NC}"
else
  echo -e "${YELLOW}Starting PostgreSQL...${NC}"
  docker run -d \
    --name hkai-postgres \
    --restart unless-stopped \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=difyai123456 \
    -e POSTGRES_DB=dify \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v hkai-pgdata:/var/lib/postgresql/data \
    -p 5432:5432 \
    postgres:15-alpine \
    postgres -c 'max_connections=100' -c 'shared_buffers=128MB'

  echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
  for i in {1..30}; do
    if docker exec hkai-postgres pg_isready -U postgres > /dev/null 2>&1; then
      echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
      break
    fi
    sleep 1
  done
fi

# --- Redis ---
if docker ps --format '{{.Names}}' | grep -q '^hkai-redis$'; then
  echo -e "${GREEN}✅ Redis already running${NC}"
else
  echo -e "${YELLOW}Starting Redis...${NC}"
  docker run -d \
    --name hkai-redis \
    --restart unless-stopped \
    -v hkai-redis-data:/data \
    -p 6379:6379 \
    redis:7-alpine \
    redis-server --requirepass difyai123456

  echo -e "${GREEN}✅ Redis started${NC}"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Infrastructure is ready!             ║${NC}"
echo -e "${GREEN}║  PostgreSQL: localhost:5432            ║${NC}"
echo -e "${GREEN}║  Redis:      localhost:6379            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
