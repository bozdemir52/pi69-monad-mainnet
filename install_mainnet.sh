#!/bin/bash
# Monad Mainnet Validator Auto-Deploy Script
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================================${NC}"
echo -e "${GREEN}🚀 Welcome to Monad Mainnet Validator Auto-Deploy!${NC}"
echo -e "${CYAN}=========================================================${NC}"

if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found! Please create it using 'cp .env.example .env' and fill in the details.${NC}"
    exit 1
fi

source .env

echo -e "\n${YELLOW}[1/6] Pre-flight Hardware Check (Doctor)...${NC}"
bash modules/00_doctor_check.sh

echo -e "\n${YELLOW}[2/6] System Prep & Network Optimizations (70k PPS UFW)...${NC}"
bash modules/01_system_prep.sh

echo -e "\n${YELLOW}[3/6] NVMe Disk & TrieDB Optimization...${NC}"
bash modules/02_disk_setup.sh

echo -e "\n${YELLOW}[4/6] Monad Core Installation & Configuration...${NC}"
bash modules/03_monad_install.sh

echo -e "\n${YELLOW}[5/6] Identity Backup...${NC}"
bash tools/backup_keys.sh

echo -e "\n${YELLOW}[6/6] Installing Watchdog Service...${NC}"
# Note: Renamed to watchdog-mainnet to prevent conflicts with testnet
sudo cp watchdog/watchdog.service /etc/systemd/system/watchdog-mainnet.service
sudo systemctl daemon-reload
sudo systemctl enable --now watchdog-mainnet.service

echo -e "\n${CYAN}=========================================================${NC}"
echo -e "${GREEN}✅ Installation Completed Successfully!${NC}"
echo -e "${CYAN}=========================================================${NC}"
