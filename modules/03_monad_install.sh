#!/bin/bash
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}⚙️ Installing Monad Core...${NC}"
if ! id "monad" &>/dev/null; then sudo useradd -m -s /bin/bash monad; fi
sudo mkdir -p /opt/monad/backup /home/monad/monad-bft/config
sudo chown -R monad:monad /opt/monad /home/monad

sudo apt-get update -y
# Installation command will be added here when the official network goes live.

source .env
cat <<EOF | sudo tee /home/monad/.env > /dev/null
MONIKER="${MONIKER}"
REMOTE_VALIDATORS_URL="${REMOTE_VALIDATORS_URL}"
REMOTE_FORKPOINT_URL="${REMOTE_FORKPOINT_URL}"
CHAIN="monad_mainnet"
EOF

sudo chown monad:monad /home/monad/.env
sudo chmod 600 /home/monad/.env
echo -e "${GREEN}✅ Auto-Repair (Soft-Reset) configurations added to .env.${NC}"

# Servis dosyasını oluştur (Anahtarlar olmasa bile servis hazır dursun)
cat <<EOF | sudo tee /etc/systemd/system/monad.service > /dev/null
[Unit]
Description=Monad Node Service
After=network.target

[Service]
User=monad
Group=monad
WorkingDirectory=/home/monad
EnvironmentFile=/home/monad/.env
ExecStart=/usr/bin/monad-node --config /home/monad/monad-bft/config.toml
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable monad
