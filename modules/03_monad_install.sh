#!/bin/bash
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${YELLOW}⚙️  Configuring Monad Core Services (BFT, Execution, RPC)...${NC}"

# Create monad user if not exists
if ! id "monad" &>/dev/null; then 
    sudo useradd -m -s /bin/bash monad
fi

# Create necessary directories
sudo mkdir -p /opt/monad/backup /home/monad/monad-bft/config
sudo chown -R monad:monad /opt/monad /home/monad

# Deploy Environment File
source .env
cat <<EOF | sudo tee /home/monad/.env > /dev/null
MONIKER="${MONIKER}"
REMOTE_VALIDATORS_URL="${REMOTE_VALIDATORS_URL}"
REMOTE_FORKPOINT_URL="${REMOTE_FORKPOINT_URL}"
CHAIN="monad_mainnet"
EOF
sudo chown monad:monad /home/monad/.env
sudo chmod 600 /home/monad/.env

# ------------------------------------------------------------------------------
# 1. Monad Execution Service
# ------------------------------------------------------------------------------
cat <<EOF | sudo tee /etc/systemd/system/monad-execution.service > /dev/null
[Unit]
Description=Monad Execution Client
After=network.target

[Service]
User=monad
EnvironmentFile=/home/monad/.env
ExecStart=/usr/bin/monad-execution --config /home/monad/monad-bft/config.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------------------------
# 2. Monad BFT (Consensus) Service
# ------------------------------------------------------------------------------
cat <<EOF | sudo tee /etc/systemd/system/monad-bft.service > /dev/null
[Unit]
Description=Monad BFT Consensus Client
After=monad-execution.service

[Service]
User=monad
EnvironmentFile=/home/monad/.env
ExecStart=/usr/bin/monad-bft --config /home/monad/monad-bft/config.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------------------------
# 3. Monad RPC Service
# ------------------------------------------------------------------------------
cat <<EOF | sudo tee /etc/systemd/system/monad-rpc.service > /dev/null
[Unit]
Description=Monad RPC Service
After=monad-bft.service

[Service]
User=monad
EnvironmentFile=/home/monad/.env
ExecStart=/usr/bin/monad-rpc --config /home/monad/monad-bft/config.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload and Enable Services
sudo systemctl daemon-reload
sudo systemctl enable monad-execution monad-bft monad-rpc

echo -e "${GREEN}✅ Monad services have been created and enabled!${NC}"
echo -e "${YELLOW}⚠️  Note: Services will start correctly once binaries are present and configured.${NC}"
