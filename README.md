# 🟣 Monad Mainnet Validator OS (v2.0)

A comprehensive, enterprise-grade guide and toolkit for deploying Monad Mainnet Full Nodes and Validators on Ubuntu 24.04. This repository follows official Monad documentation requirements and best practices for maximum performance and stability.

## ✨ Key Highlights

- **Kernel Optimized:** Designed for v6.8.0.60+ (Fixes critical freeze bugs).
- **Dual-Disk Architecture:** Separate IO paths for OS/BFT and TrieDB (Non-RAID).
- **Network Hardened:** 70,000+ PPS UDP optimization for RaptorCast.
- **Native Monitoring:** Integrated OTEL Collector and Monlog analysis.
- **Auto-Healing:** v0.12.1+ Soft-Reset and Remote Configuration support.

---

## 📋 Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Critical Kernel Check](#2-critical-kernel-check)
3. [System Preparation](#3-system-preparation)
4. [Monad Package Installation](#4-monad-package-installation)
5. [User and Directory Setup](#5-user-and-directory-setup)
6. [CPU Performance Optimization](#6-cpu-performance-optimization)
7. [TrieDB Disk Configuration](#7-triedb-disk-configuration)
8. [Firewall (UFW & iptables)](#8-firewall-ufw--iptables)
9. [OTEL Collector Setup](#9-otel-collector-setup)
10. [Node Configuration](#10-node-configuration)
11. [Keystore Generation](#11-keystore-generation)
12. [Node Signature Record](#12-node-signature-record)
13. [Authenticated UDP Setup](#13-authenticated-udp-setup)
14. [Starting Services](#14-starting-services)
15. [Monitoring and Health Checks](#15-monitoring-and-health-checks)
16. [Validator Setup](#16-validator-setup)
17. [Node Recovery Methods](#17-node-recovery-methods)
18. [Node Migration (Full Node → Validator)](#18-node-migration-full-node--validator)
19. [Key Backup & Restore](#19-key-backup--restore)
20. [Service Reference](#20-service-reference)

---

## 1. System Requirements

| Component | Minimum | Recommended |
| :--- | :--- | :--- |
| **OS** | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| **Kernel** | v6.8.0.60+ (Mandatory) | v6.8.0.60+ |
| **CPU** | 16 Cores | 16+ Cores @ 4.5GHz+ |
| **RAM** | 32 GB | 64–128 GB |
| **Storage** | 2x 2TB NVMe SSD | 2x 2TB NVMe SSD (Non-RAID) |
| **Network** | 1 Gbps | 1 Gbps+ (70,000 PPS capacity) |

> ⚠️ **CRITICAL:** The two disks MUST BE INDEPENDENT. Do not use RAID. Allocate one disk strictly for the OS/BFT and the second exclusively for TrieDB.

> ⚠️ **HyperThreading (HT) / SMT:** Must be disabled in the BIOS. These features severely degrade node performance.

---

## 2. Critical Kernel Check

There is a known critical bug in Linux kernel versions `v6.8.0.56` through `v6.8.0.59` that causes Monad nodes to freeze. Check your version first:

```bash
uname -r
```

If your version ends in `56`, `57`, `58`, or `59`, you must upgrade and reboot before proceeding:

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

After rebooting, verify the kernel is **v6.8.0.60 or higher**.

---

## 3. System Preparation

```bash
# Update the system
sudo apt update && sudo apt upgrade -y

# Install required tools
sudo apt install -y curl nvme-cli aria2 jq parted ufw linux-tools-common linux-tools-$(uname -r)
```

---

## 4. Monad Package Installation

```bash
# Add the GPG key
curl -fsSL https://pkg.category.xyz/keys/public-key.asc \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/category-labs.gpg

# Define the APT repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/category-labs.sources
Types: deb
URIs: https://pkg.category.xyz/
Suites: noble
Components: main
Signed-By: /etc/apt/keyrings/category-labs.gpg
EOF

# Install Monad and lock the version
sudo apt update
sudo apt install -y monad
sudo apt-mark hold monad
```

---

## 5. User and Directory Setup

```bash
# Create the monad user
sudo useradd -m -s /bin/bash monad

# Create necessary directories
sudo mkdir -p /home/monad/monad-bft/config \
              /home/monad/monad-bft/ledger \
              /home/monad/monad-bft/config/forkpoint \
              /home/monad/monad-bft/config/validators
```

---

## 6. CPU Performance Optimization

```bash
# Lock the CPU to maximum performance mode
sudo cpupower frequency-set -g performance

# Verify (The governor should output "performance")
cpupower frequency-info | grep "current policy"
```

---

## 7. TrieDB Disk Configuration

> ⚠️ **WARNING:** Formatting the wrong disk will destroy your operating system. Verify which disk you are targeting before proceeding.

```bash
sudo nvme list
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
```

Identify the disk with **no mount points** — it should not show `/`, `/boot`, or `swap`. This will be your TrieDB drive.

```bash
# Define the disk variable (CHANGE THIS TO YOUR ACTUAL DRIVE)
export TRIEDB_DRIVE=/dev/nvme1n1

# Create a GPT partition table
sudo parted $TRIEDB_DRIVE mklabel gpt
sudo parted $TRIEDB_DRIVE mkpart triedb 0% 100%

# Create a udev rule for the partition symlink
PARTUUID=$(lsblk -o PARTUUID $TRIEDB_DRIVE | tail -n 1)
echo "ENV{ID_PART_ENTRY_UUID}==\"$PARTUUID\", MODE=\"0666\", SYMLINK+=\"triedb\"" \
  | sudo tee /etc/udev/rules.d/99-triedb.rules

# Apply and verify udev rules
sudo udevadm trigger
sudo udevadm control --reload
sudo udevadm settle
ls -l /dev/triedb
```

### Verify LBA Configuration

```bash
sudo nvme id-ns -H $TRIEDB_DRIVE | grep 'LBA Format' | grep 'in use'
```

Expected output: `Data Size: 512 bytes ... (in use)`

If 512 bytes is **not** active, format it:

```bash
sudo nvme format --lbaf=0 $TRIEDB_DRIVE
# Verify again
sudo nvme id-ns -H $TRIEDB_DRIVE | grep 'LBA Format' | grep 'in use'
```

### Initialize TrieDB Partition

```bash
sudo systemctl start monad-mpt
journalctl -u monad-mpt -n 14 -o cat
```

---

## 8. Firewall (UFW & iptables)

> ⚠️ **RaptorCast Warning:** Monad generates ~70,000 PPS (Packets Per Second) of UDP traffic. You **must** relax anti-DDoS protections on your hosting provider's control panel (Hetzner, Latitude, etc.), or your server may get null-routed.

```bash
# Setup UFW rules
sudo ufw allow ssh
sudo ufw allow 8000/tcp
sudo ufw allow 8000/udp
sudo ufw allow 8001/udp
sudo ufw --force enable
sudo ufw status
```

```bash
# iptables rule for UDP spam protection
# Note: This rule resets on reboot. Use iptables-persistent to make it permanent.
sudo iptables -I INPUT -p udp --dport 8000 -m length --length 0:1400 -j DROP
```

### Verify Outbound Connectivity

After enabling the firewall, verify outbound connectivity on TCP port 8000:

```bash
nc -vz 64.31.29.190 8000
# Expected: Connection to 64.31.29.190 8000 port [tcp/*] succeeded!
```

---

## 9. OTEL Collector Setup

Metrics will be exposed at `http://0.0.0.0:8889/metrics`.

```bash
OTEL_VERSION="0.139.0"
OTEL_PACKAGE="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_linux_amd64.deb"

curl -fsSL "$OTEL_PACKAGE" -o /tmp/otelcol_linux_amd64.deb
sudo dpkg -i /tmp/otelcol_linux_amd64.deb
sudo cp /opt/monad/scripts/otel-config.yaml /etc/otelcol/config.yaml
sudo systemctl restart otelcol
```

---

## 10. Node Configuration

### 1. Download Configuration Files

```bash
MF_BUCKET=https://bucket.monadinfra.com

sudo curl -o /home/monad/.env $MF_BUCKET/config/mainnet/latest/.env.example
sudo curl -o /home/monad/monad-bft/config/node.toml $MF_BUCKET/config/mainnet/latest/full-node-node.toml
```

### 2. Add Auto-Recovery URLs to .env

Add the remote configuration variables to enable automatic soft resets on startup (v0.12.1+):

```bash
echo "REMOTE_VALIDATORS_URL='https://bucket.monadinfra.com/validators/mainnet/validators.toml'" \
  | sudo tee -a /home/monad/.env
echo "REMOTE_FORKPOINT_URL='https://bucket.monadinfra.com/forkpoint/mainnet/forkpoint.toml'" \
  | sudo tee -a /home/monad/.env
```

### 3. Edit node.toml Settings

```bash
sudo nano /home/monad/monad-bft/config/node.toml
```

Find and update the following fields:

```toml
# The address to receive block rewards (use burn address for a full node)
beneficiary = "0x0000000000000000000000000000000000000000"

# Your unique node name (e.g., full_hetzner-1)
node_name = "full_<PROVIDER_NAME>-1"
```

Ensure the following settings are also correct for a **public full node**:

```toml
# Under [fullnode_raptorcast]
enable_client = true

# Under [statesync]
expand_to_group = true

# Under [blocksync_override] — must remain empty for public full nodes
peers = []
```

---

## 11. Keystore Generation

```bash
# Generate and save a strong keystore password
sudo sed -i "s|^KEYSTORE_PASSWORD=$|KEYSTORE_PASSWORD='$(openssl rand -base64 32)'|" /home/monad/.env
source /home/monad/.env
sudo mkdir -p /opt/monad/backup/
echo "Keystore password: ${KEYSTORE_PASSWORD}" | sudo tee /opt/monad/backup/keystore-password-backup
```

```bash
# Generate SECP and BLS keys (with guard against overwriting existing keys)
sudo bash <<'EOF'
set -e
source /home/monad/.env

if [[ -z "$KEYSTORE_PASSWORD" || \
      -f /home/monad/monad-bft/config/id-secp || \
      -f /home/monad/monad-bft/config/id-bls ]]; then
  echo "Skipping: KEYSTORE_PASSWORD is missing or keys already exist."
  exit 1
fi

monad-keystore create \
  --key-type secp \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --password "${KEYSTORE_PASSWORD}" > /opt/monad/backup/secp-backup

monad-keystore create \
  --key-type bls \
  --keystore-path /home/monad/monad-bft/config/id-bls \
  --password "${KEYSTORE_PASSWORD}" > /opt/monad/backup/bls-backup

grep "public key" /opt/monad/backup/secp-backup /opt/monad/backup/bls-backup \
  | tee /home/monad/pubkey-secp-bls

echo "Success: New keystores generated."
EOF
```

> 🔐 **CRITICAL:** The backup files inside `/opt/monad/backup/` represent your node's identity. Store them securely **off-server** (e.g., in a password manager or secrets vault). Anyone with access to these files can take over your node's identity.

---

## 12. Node Signature Record

Generate your node's peer discovery signature:

```bash
source /home/monad/.env
monad-sign-name-record \
  --address $(curl -s4 ifconfig.me):8000 \
  --authenticated-udp-port 8001 \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --password "${KEYSTORE_PASSWORD}" \
  --self-record-seq-num 1
```

Example output:

```
self_address = "12.34.56.78:8000"
self_record_seq_num = 1
self_name_record_sig = "5995f8dc...034300"
```

Open `node.toml` and update **all three fields** in the `[peer_discovery]` section with this output:

```bash
sudo nano /home/monad/monad-bft/config/node.toml
```

```toml
[peer_discovery]
self_address = "12.34.56.78:8000"
self_record_seq_num = 1
self_name_record_sig = "<YOUR_GENERATED_SIGNATURE>"
```

---

## 13. Authenticated UDP Setup

> ⚠️ **Do not implement this step until officially instructed by the Monad Foundation.**

### Why it Matters

- Cryptographically authenticated peer connections using your existing validator keys.
- DoS protection against spoofed packets.
- ~100x faster packet verification compared to per-packet ECDSA signatures.

### Generate Auth UDP Signature

```bash
# Important: --self-record-seq-num must be GREATER than your current value in node.toml
# If node.toml shows self_record_seq_num = 1, use 2 here, etc.
source /home/monad/.env
monad-sign-name-record \
  --address $(curl -4 -s ifconfig.me):8000 \
  --authenticated-udp-port 8001 \
  --self-record-seq-num 2 \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --password "$KEYSTORE_PASSWORD"
```

### Update node.toml

Open `node.toml` (`sudo nano /home/monad/monad-bft/config/node.toml`) and apply the following changes:

**Update `[peer_discovery]` section** — paste the full output from the command above and add `self_auth_port`:

```toml
[peer_discovery]
self_address = "YOUR_IP:8000"
self_auth_port = 8001
self_record_seq_num = 2
self_name_record_sig = "<YOUR_NEW_GENERATED_SIGNATURE>"
```

**Update `[network]` section** — add the authenticated bind port:

```toml
[network]
bind_address_host = "0.0.0.0"
bind_address_port = 8000
authenticated_bind_address_port = 8001
max_rtt_ms = 300
max_mbps = 1000
```

```bash
sudo systemctl restart monad-bft
```

### Validate Auth UDP Configuration

```bash
sudo apt-get install -y yq

MF_BUCKET=https://bucket.monadinfra.com
curl -fsSL $MF_BUCKET/scripts/validate-auth-udp-config.sh | bash -s -
```

A healthy output will confirm all bootstrap peers show `auth_port=8001 ✔` and end with:

```
✔ Configuration is Auth UDP compliant, and ready for Clear UDP decommission.
```

---

## 14. Starting Services

```bash
# Set correct file permissions
sudo chown -R monad:monad /home/monad/

# Enable services to start automatically on boot
sudo systemctl enable monad-bft monad-execution monad-rpc

# --- Hard Reset (Mandatory on initial setup) ---
# Wipes local state and imports the latest network snapshot.
sudo bash /opt/monad/scripts/reset-workspace.sh

# Download and restore the Mainnet snapshot
MF_BUCKET=https://bucket.monadinfra.com
curl -sSL $MF_BUCKET/scripts/mainnet/restore-from-snapshot.sh | sudo bash

# Fetch the latest forkpoint and validator definitions
VALIDATORS_FILE=/home/monad/monad-bft/config/validators/validators.toml
curl -sSL $MF_BUCKET/scripts/mainnet/download-forkpoint.sh | sudo bash
sudo curl $MF_BUCKET/validators/mainnet/validators.toml -o $VALIDATORS_FILE
sudo chown monad:monad $VALIDATORS_FILE

# Start the node services
sudo systemctl start monad-bft monad-execution monad-rpc
```

Verify all services are running:

```bash
sudo systemctl list-units --type=service monad-bft.service monad-execution.service monad-rpc.service
```

---

## 15. Monitoring and Health Checks

### Install monad-status

```bash
sudo curl -sSL https://bucket.monadinfra.com/scripts/monad-status.sh -o /usr/local/bin/monad-status
sudo chmod +x /usr/local/bin/monad-status
monad-status
```

A healthy node will eventually display:

```
consensus:
  status: in-sync
  blockDifference: 0
statesync:
  percentage: 100.0000%
```

### Watch Live Logs

```bash
sudo journalctl -u monad-bft -f
sudo journalctl -u monad-execution -f
sudo journalctl -u monad-rpc -f
```

### Check Block Height via RPC

The RPC service starts listening on port `8080` once statesync is complete:

```bash
curl http://localhost:8080/ \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}'
```

### View TrieDB Disk Usage

```bash
monad-mpt --storage /dev/triedb
```

### BFT Log Analysis (monlog)

```bash
# Grant the monad user access to read systemd journal logs
sudo usermod -a -G systemd-journal monad

# Download and run monlog as the monad user
sudo su - monad
curl -sSL https://pub-b0d0d7272c994851b4c8af22a766f571.r2.dev/scripts/monlog -O
chmod u+x ./monlog

# Run once or watch continuously
./monlog
watch -d "./monlog"
```

### Live Consensus Info (ledger-tail)

```bash
sudo systemctl start monad-ledger-tail
journalctl -fu monad-ledger-tail
```

---

## 16. Validator Setup

You can proceed with validator setup **only after your full node is completely synchronized** (showing `status: in-sync`).

### 1. Download the Validator node.toml Template

```bash
MF_BUCKET=https://bucket.monadinfra.com
sudo curl -o /home/monad/monad-bft/config/node.toml $MF_BUCKET/config/mainnet/latest/node.toml
```

### 2. Configure Validator Settings

```bash
sudo nano /home/monad/monad-bft/config/node.toml
```

Update the following fields:

```toml
# Your wallet address to receive staking rewards
beneficiary = "0x<YOUR_VALIDATOR_REWARD_ADDRESS>"

# Your unique validator name (remove the 'full_' prefix from your previous name)
node_name = "<PROVIDER_NAME>-1"
```

Optionally configure dedicated or prioritized downstream full nodes:

```toml
# Option A: Dedicated full node
[[bootstrap.peers]]
address = "<ip>:<port>"
record_seq_num = "<record_seq_num>"
name_record_sig = "<name_record_sig>"
secp256k1_pubkey = "<full_node_pubkey>"

[[fullnode_dedicated.identities]]
secp256k1_pubkey = "<full_node_pubkey>"

# Option B: Prioritized full node
[[bootstrap.peers]]
address = "<ip>:<port>"
record_seq_num = "<record_seq_num>"
name_record_sig = "<name_record_sig>"
secp256k1_pubkey = "<full_node_pubkey>"

[[fullnode_raptorcast.full_nodes_prioritized.identities]]
secp256k1_pubkey = "<full_node_pubkey>"
```

To reload configuration changes without restarting `monad-bft`:

```bash
monad-debug-node --control-panel-ipc-path /home/monad/monad-bft/controlpanel.sock reload-config
```

### 3. Restart the Node

```bash
sudo systemctl restart monad-bft monad-execution monad-rpc
```

### 4. Register as a Validator via Staking CLI

Use the official [staking-sdk-cli](https://github.com/monad-xyz/staking-sdk-cli) tool to call `addValidator` on the staking precompile. Refer to the onboarding workflow in the staking documentation for exact usage.

Your validator must meet **all three** conditions to become active in the next epoch:

| Condition | Value |
| :--- | :--- |
| Minimum self-stake | 100,000 MON |
| Minimum total stake required | 10,000,000 MON |
| Must be in top validators by stake | Top 200 |

---

## 17. Node Recovery Methods

| Method | Speed | When to Use |
| :--- | :--- | :--- |
| **Soft Reset** | Fast | Node tip is close to the network; short outages. |
| **Hard Reset** | Medium | Node tip is far behind the network; long outages. |
| **Full Replay** | Slow | Required only for RPC providers needing complete historical state with no gaps. |

---

### Soft Reset (Automatic — v0.12.1+)

If `REMOTE_VALIDATORS_URL` and `REMOTE_FORKPOINT_URL` are defined in your `.env` file, the node will automatically fetch fresh configs on startup. Simply restart:

```bash
sudo systemctl restart monad-bft monad-execution monad-rpc
```

Verify services are running:

```bash
sudo systemctl list-units --type=service monad-bft.service monad-execution.service monad-rpc.service
```

---

### Soft Reset (Manual)

Use this if automatic remote fetching is not configured or you prefer to update configs manually.

```bash
# 1. Stop services
sudo systemctl stop monad-bft monad-execution monad-rpc

# 2. Fetch latest forkpoint and validators
MF_BUCKET=https://bucket.monadinfra.com
VALIDATORS_FILE=/home/monad/monad-bft/config/validators/validators.toml

curl -sSL $MF_BUCKET/scripts/mainnet/download-forkpoint.sh | sudo bash
sudo curl $MF_BUCKET/validators/mainnet/validators.toml -o $VALIDATORS_FILE
sudo chown monad:monad $VALIDATORS_FILE

# 3. Restart services
sudo systemctl start monad-bft monad-execution monad-rpc
```

---

### Hard Reset

Wipes local state completely and re-imports from a fresh network snapshot. Use when the node is far out of sync.

```bash
# 1. Stop services and wipe workspace
sudo bash /opt/monad/scripts/reset-workspace.sh

# 2. Restore snapshot — Monad Foundation provider:
MF_BUCKET=https://bucket.monadinfra.com
curl -sSL $MF_BUCKET/scripts/mainnet/restore-from-snapshot.sh | sudo bash

# Alternative — Category Labs provider:
# CL_BUCKET=https://pub-b0d0d7272c994851b4c8af22a766f571.r2.dev
# curl -sSL $CL_BUCKET/scripts/mainnet/restore_from_snapshot.sh | sudo bash

# 3. Fetch latest forkpoint and validators
VALIDATORS_FILE=/home/monad/monad-bft/config/validators/validators.toml
curl -sSL $MF_BUCKET/scripts/mainnet/download-forkpoint.sh | sudo bash
sudo curl $MF_BUCKET/validators/mainnet/validators.toml -o $VALIDATORS_FILE
sudo chown monad:monad $VALIDATORS_FILE

# 4. Start services
sudo systemctl start monad-bft monad-execution monad-rpc
```

---

### Full Replay (RPC Providers Only)

Use this to backfill all historical state with no gaps. Requires SSH access to a **healthy remote mainnet node** (`REMOTE_HOST`) that was running during your downtime.

```bash
# 1. SSH into the faulty node as the monad user
# 2. Verify statesync_threshold is 600
grep statesync_threshold /home/monad/monad-bft/config/node.toml

# 3. Stop services
sudo systemctl stop monad-bft monad-execution monad-rpc
```

Create `manual-sync.sh` and run it. Interrupt with `Ctrl+C` once output stops:

```bash
#!/usr/bin/env bash
set -euo pipefail
source .env

: "${SSH_PORT:?SSH_PORT must be set}"
: "${REMOTE_HOST:?REMOTE_HOST must be set}"
: "${CHAIN:?CHAIN must be set}"

rsync -avP -e "ssh -p $SSH_PORT" \
  "monad@$REMOTE_HOST:/home/monad/monad-bft/ledger/headers/*_head" \
  /home/monad/monad-bft/ledger/headers/

rsync -avP --ignore-existing -e "ssh -p $SSH_PORT" \
  "monad@$REMOTE_HOST:/home/monad/monad-bft/ledger/" \
  /home/monad/monad-bft/ledger/

/usr/local/bin/monad \
  --chain "$CHAIN" \
  --db /dev/triedb \
  --block_db /home/monad/monad-bft/ledger \
  --sq_thread_cpu 1 \
  --log_level INFO
```

```bash
REMOTE_HOST=node1.<provider>.com SSH_PORT=22 CHAIN=monad_mainnet bash manual-sync.sh
```

Once the first script completes, create and run `manual-sync-step-2.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source .env

rsync -av -e "ssh -p $SSH_PORT" \
  "monad@$REMOTE_HOST:/home/monad/monad-bft/config/forkpoint/forkpoint.rlp" \
  /home/monad/monad-bft/config/forkpoint/
rsync -av -e "ssh -p $SSH_PORT" \
  "monad@$REMOTE_HOST:/home/monad/monad-bft/config/forkpoint/forkpoint.toml" \
  /home/monad/monad-bft/config/forkpoint/forkpoint.toml
rsync -av -e "ssh -p $SSH_PORT" \
  "monad@$REMOTE_HOST:/home/monad/monad-bft/config/validators/validators.toml" \
  /home/monad/monad-bft/config/validators/validators.toml

systemctl start monad-bft monad-execution monad-rpc
```

```bash
REMOTE_HOST=node1.<provider>.com SSH_PORT=22 CHAIN=monad_mainnet bash manual-sync-step-2.sh
```

---

## 18. Node Migration (Full Node → Validator)

Use this to promote a synced full node to validator with minimal downtime. This is the recommended approach for planned or unplanned validator maintenance, as there is currently no slashing on mainnet, but downtime does result in lost rewards.

```bash
# 1. Backup current full node configuration files
sudo mv /home/monad/monad-bft/config/node.toml /opt/monad/backup/node.toml.fullnode.bak
sudo mv /home/monad/monad-bft/config/id-secp /opt/monad/backup/id-secp.fullnode.bak
sudo mv /home/monad/monad-bft/config/id-bls /opt/monad/backup/id-bls.fullnode.bak

# 2. Transfer the validator's id-secp, id-bls, and node.toml to this node
# (Copy from the original validator server via scp or your preferred method)

# 3. Generate a new name-record signature for the new IP address
#    IMPORTANT: --self-record-seq-num must be greater than the current value in node.toml
source /home/monad/.env
monad-sign-name-record \
  --address $(curl -s4 ifconfig.me):8000 \
  --node-config /home/monad/monad-bft/config/node.toml \
  --authenticated-udp-port 8001 \
  --self-record-seq-num 2 \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --password "$KEYSTORE_PASSWORD"

# 4. Update node.toml [peer_discovery] with the output above (all 3 fields)
sudo nano /home/monad/monad-bft/config/node.toml
```

Before switching, verify:

- `enable_publisher = true` is set
- `enable_client = true` is set
- `expand_to_group = true` is set
- `beneficiary` address is correctly copied from the validator's `node.toml`

```bash
# 5. Stop the original validator's services (on the OLD server)
sudo systemctl stop monad-bft monad-rpc monad-execution

# 6. Stop this full node's services and restart as the new validator
sudo systemctl stop monad-bft monad-rpc monad-execution
sleep 1
sudo systemctl start monad-bft monad-rpc monad-execution

# 7. Verify the new validator is running correctly
sudo systemctl status monad-bft monad-execution monad-rpc
journalctl -fu monad-bft
```

> 📝 **Note:** Every node on the network must have a unique `node_name`. Ensure no two servers share the same name at any point during migration.

---

## 19. Key Backup & Restore

### Export Key Backups

Run this to re-export your keys if backup files are missing or need to be refreshed. Existing backups are preserved with a timestamp suffix before being overwritten.

```bash
source /home/monad/.env

[ -f /opt/monad/backup/secp-backup ] && \
  mv /opt/monad/backup/secp-backup "/opt/monad/backup/secp-backup.$(date +%Y%m%d%H%M%S).bak"
[ -f /opt/monad/backup/bls-backup ] && \
  mv /opt/monad/backup/bls-backup "/opt/monad/backup/bls-backup.$(date +%Y%m%d%H%M%S).bak"

monad-keystore recover \
  --password "$KEYSTORE_PASSWORD" \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --key-type secp > /opt/monad/backup/secp-backup

monad-keystore recover \
  --password "$KEYSTORE_PASSWORD" \
  --keystore-path /home/monad/monad-bft/config/id-bls \
  --key-type bls > /opt/monad/backup/bls-backup
```

### Restore Keys from Backups

Use this to restore your node identity on a new server from a previous backup.

```bash
source /home/monad/.env

# Backup any existing keystore files before overwriting
[ -f /home/monad/monad-bft/config/id-secp ] && \
  mv /home/monad/monad-bft/config/id-secp "/home/monad/monad-bft/config/id-secp.$(date +%Y%m%d%H%M%S).bak"
[ -f /home/monad/monad-bft/config/id-bls ] && \
  mv /home/monad/monad-bft/config/id-bls "/home/monad/monad-bft/config/id-bls.$(date +%Y%m%d%H%M%S).bak"

SECP_IKM=$(grep -E "Keystore secret:|Keep your IKM secure:" /opt/monad/backup/secp-backup | awk '{print $NF}')
BLS_IKM=$(grep -E "Keystore secret:|Keep your IKM secure:" /opt/monad/backup/bls-backup | awk '{print $NF}')

monad-keystore import \
  --ikm "$SECP_IKM" \
  --password "$KEYSTORE_PASSWORD" \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --key-type secp

monad-keystore import \
  --ikm "$BLS_IKM" \
  --password "$KEYSTORE_PASSWORD" \
  --keystore-path /home/monad/monad-bft/config/id-bls \
  --key-type bls
```

> 🔐 For validators especially: losing your keys means you cannot migrate your validator, and re-registering with a new identity requires moving all delegations manually. Always store backups off-server.

---

## 20. Service Reference

| Service | Description |
| :--- | :--- |
| `monad-bft` | The Consensus client. The heart of the network. |
| `monad-execution` | The Execution client. Processes EVM smart contracts. |
| `monad-rpc` | The public-facing RPC server (Default port: 8080). |
| `monad-mpt` | One-time service to format and initialize the TrieDB disk. |
| `monad-cruft` | Hourly cron-like service to prune old logs and ledger artifacts. |
| `otelcol` | OpenTelemetry daemon for aggregating node metrics. |

### Important Paths

| Path | Contents |
| :--- | :--- |
| `/home/monad/.env` | Service environment variables |
| `/home/monad/monad-bft/config/node.toml` | Consensus parameters and peer config |
| `/home/monad/monad-bft/config/forkpoint/` | Consensus quorum checkpoint files |
| `/home/monad/monad-bft/config/validators/` | Validator set files |
| `/home/monad/monad-bft/ledger/` | BFT block headers and bodies |
| `/dev/triedb` | TrieDB database device |
| `/opt/monad/backup/` | Key and password backups |

### Artifact Retention (monad-cruft)

Control how long artifacts are retained before deletion by adding these variables to `/home/monad/.env`:

```bash
RETENTION_LEDGER=600       # Ledger files (default: 600 min = 10 hours)
RETENTION_WAL=300          # WAL files (default: 300 min = 5 hours)
RETENTION_FORKPOINT=300    # Forkpoint files (default: 300 min = 5 hours)
RETENTION_VALIDATORS=43200 # Validator files (default: 43200 min = 30 days)
```

---

## 📢 Stay Updated

- Join the [Monad Node Announcements Telegram Group](https://t.me/monadnodeannouncements)
- Join the [Monad Developer Discord](https://discord.gg/monad) and follow the `#mainnet-fullnode-announcements` channel
