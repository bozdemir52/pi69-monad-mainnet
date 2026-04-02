#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

TARGET_DIR="$HOME/monad_safe_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${TARGET_DIR}/validator_keys_${TIMESTAMP}.tar.gz"

if [ ! -f "/opt/monad/backup/secp-backup" ]; then
    echo -e "${RED}⚠️ Key dosyaları bulunamadı, node kurulumu bekleniyor.${NC}"
    exit 0
fi

mkdir -p "$TARGET_DIR"
sudo tar -czf "$BACKUP_FILE" -C "/opt/monad/backup" secp-backup bls-backup
chmod 600 "$BACKUP_FILE"

echo -e "${GREEN}✅ Yedekleme Başarılı: ${BACKUP_FILE}${NC}"
echo -e "${RED}🚨 LÜTFEN BU DOSYAYI KİŞİSEL BİLGİSAYARINIZA İNDİRİN!${NC}"
