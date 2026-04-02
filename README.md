# 🚀 Pi69 Monad Mainnet Validator OS

A complete, enterprise-grade automated deployment and lifecycle management system for Monad Mainnet Validators. Built for maximum uptime, security, and zero-headache operations.

## ✨ Features
- **🩺 Pre-Flight Doctor:** Hardware check against Monad HCL (16+ Cores, NVMe IOPS, Kernel v6.8.0.60+).
- **🛡️ Network Optimized:** 50,000+ PPS RaptorCast consensus traffic UFW rules.
- **💾 Storage Tuned:** NVMe Zero-Latency scheduler optimizations for TrieDB.
- **🤖 Auto-Healing:** Pre-configured with Mainnet `.env` URLs for automatic soft-resets (v0.12.1+).
- **🧰 Day-2 Operations Toolkit:** Validator Migration, Hard Resets via snapshots, and Key Backups.
- **🚨 24/7 Watchdog:** Hardware and node status monitoring via Telegram.

## 🚀 Quick Start
```bash
git clone [https://github.com/YOUR_USERNAME/pi69-monad-mainnet.git](https://github.com/YOUR_USERNAME/pi69-monad-mainnet.git)
cd pi69-monad-mainnet
cp .env.example .env
nano .env # Edit your configurations
sudo bash install_mainnet.sh

**📄 `.env.example`**
```ini
# ==========================================
# Pi69 Monad Mainnet Configuration
# ==========================================

MONIKER="Pi69-Validator"

# --- AUTOMATIC SOFT-RESET URLS (v0.12.1+) ---
REMOTE_VALIDATORS_URL="https://bucket.monadinfra.com/validators/mainnet/validators.toml"
REMOTE_FORKPOINT_URL="https://bucket.monadinfra.com/scripts/mainnet/download-forkpoint.sh"

# --- WATCHDOG & ALERTS ---
TELEGRAM_BOT_TOKEN="your_telegram_bot_token_here"
TELEGRAM_CHAT_ID="your_telegram_chat_id_here"
