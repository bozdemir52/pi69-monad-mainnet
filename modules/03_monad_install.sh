#!/bin/bash
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}⚙️ Monad Core Kuruluyor...${NC}"
if ! id "monad" &>/dev/null; then sudo useradd -m -s /bin/bash monad; fi
sudo mkdir -p /opt/monad/backup /home/monad/monad-bft/config
sudo chown -R monad:monad /opt/monad /home/monad

sudo apt-get update -y
# Kurulum komutu resmi ağ yayına girdiğinde buraya eklenecek.

source .env
cat <<EOF | sudo tee /home/monad/.env > /dev/null
MONIKER="${MONIKER}"
REMOTE_VALIDATORS_URL="${REMOTE_VALIDATORS_URL}"
REMOTE_FORKPOINT_URL="${REMOTE_FORKPOINT_URL}"
CHAIN="monad_mainnet"
EOF

sudo chown monad:monad /home/monad/.env
sudo chmod 600 /home/monad/.env
echo -e "${GREEN}✅ Otomatik Onarım (Soft-Reset) .env'ye işlendi.${NC}"
