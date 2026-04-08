#!/bin/bash
# Monad Full System Cleanup Script
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}⚠️  WARNING: This will delete ALL Monad data, services, and keys!${NC}"
read -p "Are you sure you want to proceed? (y/N): " confirm
if [[ "$confirm" != [yY] ]]; then exit 0; fi

echo -e "${YELLOW}🛑 Stopping and disabling all Monad services...${NC}"
sudo systemctl stop monad-bft monad-execution monad-rpc watchdog-mainnet 2>/dev/null || true
sudo systemctl disable monad-bft monad-execution monad-rpc watchdog-mainnet 2>/dev/null || true

echo -e "${YELLOW}🗑️ Removing systemd service files...${NC}"
sudo rm -f /etc/systemd/system/monad-bft.service
sudo rm -f /etc/systemd/system/monad-execution.service
sudo rm -f /etc/systemd/system/monad-rpc.service
sudo rm -f /etc/systemd/system/watchdog-mainnet.service
sudo systemctl daemon-reload

echo -e "${YELLOW}📁 Deleting data directories and users...${NC}"
sudo rm -rf /opt/monad
sudo userdel -r monad 2>/dev/null || true

echo -e "${YELLOW}🔥 Cleaning up network rules (iptables)...${NC}"
sudo iptables -D INPUT -p udp -m hashlimit --hashlimit-upto 70000/sec --hashlimit-burst 70000 --hashlimit-mode srcip --hashlimit-name monad_consensus -j ACCEPT 2>/dev/null || true

echo -e "${GREEN}✅ System cleaned successfully! You can now perform a fresh installation.${NC}"
