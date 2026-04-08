#!/bin/bash
set -e
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

BACKUP_PATH="$HOME/monad_safe_backups"
if [ ! -d "$BACKUP_PATH" ]; then
    echo -e "${RED}❌ ERROR: Backup directory not found!${NC}"; exit 1
fi

sudo systemctl stop monad-bft monad-execution monad-rpc
LATEST_BACKUP=$(ls -t $BACKUP_PATH/validator_keys_*.tar.gz | head -1)
sudo tar -xzf "$LATEST_BACKUP" -C /opt/monad/backup/

sudo chown -R monad:monad /opt/monad/backup/
sudo chmod 600 /opt/monad/backup/*-backup
sudo systemctl start monad-bft monad-execution monad-rpc

echo -e "${GREEN}✅ Node promoted to Validator! Do not forget to shut down the old server.${NC}"
