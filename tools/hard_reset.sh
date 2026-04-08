#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}🚨 MONAD HARD RESET TOOL 🚨${NC}"
read -p "The entire database will be deleted. Are you sure? (y/N): " confirm
if [[ "$confirm" != [yY] ]]; then exit 0; fi

echo "1) Monad Foundation 2) Category Labs"
read -p "Snapshot Provider (1/2): " provider_choice

sudo systemctl stop monad-bft monad-execution monad-rpc
sudo bash /opt/monad/scripts/reset-workspace.sh

if [ "$provider_choice" == "2" ]; then
    curl -sSL https://pub-b0d0d7272c994851b4c8af22a766f571.r2.dev/scripts/mainnet/restore_from_snapshot.sh | sudo bash
else
    curl -sSL https://bucket.monadinfra.com/scripts/mainnet/restore-from-snapshot.sh | sudo bash
fi

sudo systemctl start monad-bft monad-execution monad-rpc
echo -e "${GREEN}✅ Hard Reset Successful!${NC}"
