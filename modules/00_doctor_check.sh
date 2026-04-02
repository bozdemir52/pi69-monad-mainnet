#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}🔍 Sistem Mainnet standartları için taranıyor...${NC}"

KERNEL_VER=$(uname -r)
if [[ "$KERNEL_VER" == *"6.8.0-56"* || "$KERNEL_VER" == *"6.8.0-57"* || "$KERNEL_VER" == *"6.8.0-58"* || "$KERNEL_VER" == *"6.8.0-59"* ]]; then
    echo -e "${RED}❌ KRİTİK HATA: Yasaklı Kernel sürümündesin ($KERNEL_VER). Kurulum durduruldu!${NC}"
    exit 1
fi

CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 16 ]; then
    echo -e "${RED}❌ KRİTİK HATA: Sadece $CPU_CORES çekirdek bulundu. Minimum 16 şarttır!${NC}"
    exit 1
fi

echo -e "${GREEN}🎯 Sistem Check-Up'ı başarıyla geçti.${NC}"
