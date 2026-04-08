#!/bin/bash
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}📦 Gerekli paketler yükleniyor...${NC}"
sudo apt update -y
sudo apt install -y aria2 curl wget jq ufw python3-pip python3-venv linux-tools-common linux-tools-generic

echo -e "${YELLOW}🌐 Python Watchdog bağımlılıkları yükleniyor...${NC}"
sudo pip3 install requests psutil --break-system-packages || true

echo -e "${YELLOW}🔥 Monad RaptorCast için PPS Limitleri Ayarlanıyor...${NC}"
sudo iptables -A INPUT -p udp -m hashlimit --hashlimit-upto 70000/sec --hashlimit-burst 70000 --hashlimit-mode srcip --hashlimit-name monad_consensus -j ACCEPT

echo -e "${GREEN}✅ Sistem bağımlılıkları tamamlandı!${NC}"
