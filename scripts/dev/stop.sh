#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping hkai-workflow Studio services...${NC}"

# Kill processes by port
kill $(lsof -ti:${HKAI_API_PORT:-5001} 2>/dev/null) 2>/dev/null && echo -e "  ${GREEN}✅ API stopped${NC}" || echo -e "  ${YELLOW}⚠️  API not running${NC}"
kill $(lsof -ti:${HKAI_WEB_PORT:-3000} 2>/dev/null) 2>/dev/null && echo -e "  ${GREEN}✅ Web stopped${NC}" || echo -e "  ${YELLOW}⚠️  Web not running${NC}"

# Kill Celery workers
pkill -f "celery.*worker" 2>/dev/null && echo -e "  ${GREEN}✅ Worker stopped${NC}" || echo -e "  ${YELLOW}⚠️  Worker not running${NC}"

echo ""
echo -e "${YELLOW}Stop PostgreSQL and Redis? [y/N]${NC}"
read -r stop_infra
if [[ "$stop_infra" =~ ^[Yy]$ ]]; then
  brew services stop postgresql@15 2>/dev/null && echo -e "  ${GREEN}✅ PostgreSQL stopped${NC}" || true
  brew services stop redis 2>/dev/null && echo -e "  ${GREEN}✅ Redis stopped${NC}" || true
fi

echo -e "${GREEN}Done.${NC}"
