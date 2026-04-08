#!/bin/bash
# Monad Mainnet Validator Auto-Deploy Script
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================================${NC}"
echo -e "${GREEN}🚀 Monad Mainnet Validator Kurulumuna Hoş Geldiniz!${NC}"
echo -e "${CYAN}=========================================================${NC}"

if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env dosyası bulunamadı! Lütfen 'cp .env.example .env' komutuyla oluşturup içini doldurun.${NC}"
    exit 1
fi

source .env

echo -e "\n${YELLOW}[1/6] Uçuş Öncesi Donanım Kontrolü (Doctor)...${NC}"
bash modules/00_doctor_check.sh

echo -e "\n${YELLOW}[2/6] Sistem Hazırlığı & Ağ Optimizasyonları (50k PPS UFW)...${NC}"
bash modules/01_system_prep.sh

echo -e "\n${YELLOW}[3/6] NVMe Disk & TrieDB Optimizasyonu...${NC}"
bash modules/02_disk_setup.sh

echo -e "\n${YELLOW}[4/6] Monad Core Kurulumu & Yapılandırma...${NC}"
bash modules/03_monad_install.sh

echo -e "\n${YELLOW}[5/6] Kimlik Yedekleme...${NC}"
bash tools/backup_keys.sh

echo -e "\n${YELLOW}[6/6] Watchdog Servisi Kuruluyor...${NC}"
sudo cp watchdog/watchdog.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now watchdog.service

echo -e "\n${CYAN}=========================================================${NC}"
echo -e "${GREEN}✅ Kurulum Başarıyla Tamamlandı!${NC}"
echo -e "${CYAN}=========================================================${NC}"
