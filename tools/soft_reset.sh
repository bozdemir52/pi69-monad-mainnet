#!/bin/bash
# Monad Soft Reset & Auto-Repair Tool
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${YELLOW}🔄 Initiating Monad Soft Reset (Auto-Repair)...${NC}"

if [ -f "/home/monad/.env" ]; then
    source /home/monad/.env
else
    echo -e "${RED}❌ Error: .env file not found!${NC}"; exit 1
fi

echo -e "${YELLOW}🛠 Stopping Monad Services (BFT, Execution, RPC)...${NC}"
sudo systemctl stop monad-bft monad-execution monad-rpc

echo -e "${YELLOW}🌐 Fetching network parameters...${NC}"
curl -sSL "$REMOTE_FORKPOINT_URL" | sudo bash

echo -e "${YELLOW}🚀 Restarting Monad Services...${NC}"
sudo systemctl start monad-bft monad-execution monad-rpc

echo -e "${GREEN}✅ Soft Reset completed! Checking services status...${NC}"
sudo systemctl status monad-bft --no-pager
