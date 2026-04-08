Markdown# Monad Mainnet Validator OS (v2.0)

A comprehensive, enterprise-grade guide and toolkit for deploying Monad Mainnet Full Nodes and Validators on Ubuntu 24.04. This repository follows official Monad HCL requirements and best practices for maximum performance and stability.

## ✨ Key Highlights
* **Kernel Optimized:** Designed for v6.8.0.60+ (Fixes critical freeze bugs).
* **Dual-Disk Architecture:** Separate IO paths for OS/BFT and TrieDB (Non-RAID).
* **Network Hardened:** 70,000+ PPS UDP optimization for RaptorCast.
* **Native Monitoring:** Integrated OTEL Collector and Monlog analysis.
* **Auto-Healing:** v0.12.1+ Soft-Reset and Remote Configuration support.

---

# Monad Mainnet Node Kurulum Rehberi

Bu rehber, Ubuntu 24.04 üzerinde Monad Mainnet Full Node ve Validator kurulumunu baştan sona kapsamaktadır.

## 📋 İçindekiler
1. [Sistem Gereksinimleri](#1-sistem-gereksinimleri)
2. [Kritik Kernel Kontrolü](#2-kritik-kernel-kontrolü)
3. [Sistem Hazırlığı](#3-sistem-hazırlığı)
4. [Monad Paket Kurulumu](#4-monad-paket-kurulumu)
5. [Kullanıcı ve Dizin Yapısı](#5-kullanıcı-ve-dizin-yapısı)
6. [CPU Performans Optimizasyonu](#6-cpu-performans-optimizasyonu)
7. [TrieDB Disk Yapılandırması](#7-triedb-disk-yapılandırması)
8. [Güvenlik Duvarı (Firewall)](#8-güvenlik-duvarı-firewall)
9. [OTEL Collector Kurulumu](#9-otel-collector-kurulumu)
10. [Node Yapılandırması](#10-node-yapılandırması)
11. [Keystore Oluşturma](#11-keystore-oluşturma)
12. [Node İmza Kaydı](#12-node-imza-kaydı)
13. [Authenticated UDP Kurulumu](#13-authenticated-udp-kurulumu)
14. [Servisleri Başlatma](#14-servisleri-başlatma)
15. [İzleme ve Durum Kontrolü](#15-izleme-ve-durum-kontrolü)
16. [Validator Kurulumu](#16-validator-kurulumu)
17. [Node Kurtarma Yöntemleri](#17-node-kurtarma-yöntemleri)
18. [Node Migrasyonu](#18-node-migrasyonu-full-node--validator)
19. [Key Yedekleme ve Geri Yükleme](#19-key-yedekleme-ve-geri-yükleme)
20. [Servis Referansı](#20-servis-referansı)

---

## 1. Sistem Gereksinimleri

| Bileşen | Minimum | Önerilen |
| :--- | :--- | :--- |
| **İşletim Sistemi** | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| **Kernel** | v6.8.0.60+ (Zorunlu) | v6.8.0.60+ |
| **CPU** | 16 Çekirdek | 16+ Çekirdek @ 4.5GHz+ |
| **RAM** | 32 GB | 64–128 GB |
| **Disk** | 2x 2TB NVMe SSD | 2x 2TB NVMe SSD (RAID'siz) |
| **Ağ** | 1 Gbps | 1 Gbps+ (70.000 PPS kapasiteli) |

> ⚠️ **Kritik:** İki disk BAĞIMSIZ olmalı, RAID kesinlikle kullanılmamalıdır. Bir disk OS/BFT için, diğeri yalnızca TrieDB için ayrılmalıdır.
> ⚠️ **HyperThreading (HT) / SMT:** BIOS ayarlarından devre dışı bırakılmalıdır. Bu özellikler node performansını düşürür.

---

## 2. Kritik Kernel Kontrolü

Linux kernel `v6.8.0.56` – `v6.8.0.59` arasında Monad node'unu donduran kritik bir hata mevcuttur. Versiyonunuzu kontrol edin:

```bash
uname -r
```
Sürümünüz 56, 57, 58 veya 59 ise güncelleme yapıp yeniden başlatın:

```Bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```
## 3. Sistem Hazırlığı

```Bash
# Sistemi güncelle
apt update && apt upgrade -y

# Gerekli araçları kur
apt install -y curl nvme-cli aria2 jq parted ufw linux-tools-common linux-tools-$(uname -r)
```
## 4. Monad Paket Kurulumu

```Bash
# GPG anahtarını ekle
curl -fsSL [https://pkg.category.xyz/keys/public-key.asc](https://pkg.category.xyz/keys/public-key.asc) | gpg --dearmor --yes -o /etc/apt/keyrings/category-labs.gpg

# APT deposunu tanımla
cat <<EOF > /etc/apt/sources.list.d/category-labs.sources
Types: deb
URIs: [https://pkg.category.xyz/](https://pkg.category.xyz/)
Suites: noble
Components: main
Signed-By: /etc/apt/keyrings/category-labs.gpg
EOF

# Monad'ı kur ve sürümü kilitle
apt update
apt install -y monad
apt-mark hold monad
```
## 5. Kullanıcı ve Dizin Yapısı

```Bash
# monad kullanıcısı oluştur
useradd -m -s /bin/bash monad

# Gerekli dizinleri oluştur
mkdir -p /home/monad/monad-bft/config \
         /home/monad/monad-bft/ledger \
         /home/monad/monad-bft/config/forkpoint \
         /home/monad/monad-bft/config/validators
```
# 6. CPU Performans Optimizasyonu

```Bash
# CPU'yu maksimum performans moduna kilitle
sudo cpupower frequency-set -g performance

# Doğrulama (Governor: "performance" göstermeli)
cpupower frequency-info | grep "current policy"
```
# 7. TrieDB Disk Yapılandırması
⚠️ Uyarı: Yanlış diski formatlamak işletim sisteminizi bozar. Devam etmeden önce hangi diski kullanacağınızı doğrulayın:

```Bash
nvme list
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
```
Mount noktası olmayan (/, /boot, swap göstermeyen) diski TrieDB için kullanın.

```Bash
# Disk değişkenini tanımla (KENDİ DİSKİNİZE GÖRE DEĞİŞTİRİN)
export TRIEDB_DRIVE=/dev/nvme1n1

# GPT bölüm tablosu oluştur
parted $TRIEDB_DRIVE mklabel gpt
parted $TRIEDB_DRIVE mkpart triedb 0% 100%

# udev kuralı oluştur
PARTUUID=$(lsblk -o PARTUUID $TRIEDB_DRIVE | tail -n 1)
echo "ENV{ID_PART_ENTRY_UUID}==\"$PARTUUID\", MODE=\"0666\", SYMLINK+=\"triedb\"" | tee /etc/udev/rules.d/99-triedb.rules

# udev kurallarını uygula ve doğrula
udevadm trigger
udevadm control --reload
udevadm settle
ls -l /dev/triedb
```
LBA Yapılandırmasını Doğrula:

```Bash
nvme id-ns -H $TRIEDB_DRIVE | grep 'LBA Format' | grep 'in use'
```
Beklenen çıktı: Data Size: 512 bytes ... (in use)
Eğer 512 byte aktif değilse: nvme format --lbaf=0 $TRIEDB_DRIVE
TrieDB Bölümünü Formatla:

```Bash
systemctl start monad-mpt
journalctl -u monad-mpt -n 14 -o cat
```
# 8. Güvenlik Duvarı (Firewall)
⚠️ RaptorCast Uyarısı: Monad ~70.000 PPS UDP trafiği üretir. Sunucu sağlayıcınızın anti-DDoS korumalarını gevşetin.

```Bash
# UFW kuralları
ufw allow ssh
ufw allow 8000/tcp
ufw allow 8000/udp
ufw allow 8001/tcp
ufw allow 8001/udp
ufw --force enable
ufw status

# UDP spam koruması için iptables kuralı
iptables -I INPUT -p udp --dport 8000 -m length --length 0:1400 -j DROP
```

# 9. OTEL Collector Kurulumu
Metrikler http://0.0.0.0:8889/metrics adresinden izlenebilir.

```Bash
OTEL_VERSION="0.139.0"
OTEL_PACKAGE="[https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v$](https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v$){OTEL_VERSION}/otelcol_${OTEL_VERSION}_linux_amd64.deb"

curl -fsSL "$OTEL_PACKAGE" -o /tmp/otelcol_linux_amd64.deb
dpkg -i /tmp/otelcol_linux_amd64.deb
cp /opt/monad/scripts/otel-config.yaml /etc/otelcol/config.yaml
systemctl restart otelcol
```

# 10. Node Yapılandırması

```Bash
MF_BUCKET=[https://bucket.monadinfra.com](https://bucket.monadinfra.com)
curl -o /home/monad/.env $MF_BUCKET/config/mainnet/latest/.env.example
curl -o /home/monad/monad-bft/config/node.toml $MF_BUCKET/config/mainnet/latest/full-node-node.toml
```
/home/monad/.env Dosyasına Eklenecekler (Otomatik Kurtarma İçin):

```Bash
REMOTE_VALIDATORS_URL='[https://bucket.monadinfra.com/validators/mainnet/validators.toml](https://bucket.monadinfra.com/validators/mainnet/validators.toml)'
REMOTE_FORKPOINT_URL='[https://bucket.monadinfra.com/forkpoint/mainnet/forkpoint.toml](https://bucket.monadinfra.com/forkpoint/mainnet/forkpoint.toml)'
```
/home/monad/monad-bft/config/node.toml Ayarları:

Ini, TOML# Ödül alacak adres
beneficiary = "0x0000000000000000000000000000000000000000"
# Benzersiz node adı
node_name = "your_node_name"
```
# 11. Keystore Oluşturma

```Bash
# Güçlü bir keystore şifresi oluştur
sed -i "s|^KEYSTORE_PASSWORD=$|KEYSTORE_PASSWORD='$(openssl rand -base64 32)'|" /home/monad/.env
source /home/monad/.env
mkdir -p /opt/monad/backup/
echo "Keystore password: ${KEYSTORE_PASSWORD}" > /opt/monad/backup/keystore-password-backup

# SECP ve BLS anahtarları oluştur
monad-keystore create --key-type secp --keystore-path /home/monad/monad-bft/config/id-secp --password "${KEYSTORE_PASSWORD}" > /opt/monad/backup/secp-backup
monad-keystore create --key-type bls --keystore-path /home/monad/monad-bft/config/id-bls --password "${KEYSTORE_PASSWORD}" > /opt/monad/backup/bls-backup

grep "public key" /opt/monad/backup/secp-backup /opt/monad/backup/bls-backup | tee /home/monad/pubkey-secp-bls
```
🔐 Kritik: /opt/monad/backup/ içindeki dosyaları node dışında güvenli bir yerde saklayın.

# 12. Node İmza Kaydı

```Bash
source /home/monad/.env
monad-sign-name-record \
  --address $(curl -s4 ifconfig.me):8000 \
  --authenticated-udp-port 8001 \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --password "${KEYSTORE_PASSWORD}" \
  --self-record-seq-num 1
```
Çıktıyı node.toml dosyasının [peer_discovery] bölümüne yapıştırın.

# 13. Authenticated UDP Kurulumu
⚠️ Monad Foundation'dan bildirim gelene kadar bu adımı uygulamayın.

```Bash
# Port 8001'i güvenlik duvarında aç
sudo ufw allow 8001/udp comment 'monad authenticated udp'

source /home/monad/.env
monad-sign-name-record \
  --address $(curl -4 -s ifconfig.me):8000 \
  --authenticated-udp-port 8001 \
  --self-record-seq-num 1 \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --password "$KEYSTORE_PASSWORD"
```

# 14. Servisleri Başlatma

```Bash
# Dosya izinlerini ayarla
chown -R monad:monad /home/monad/

# Servisleri etkinleştir
systemctl enable monad-bft monad-execution monad-rpc

# Hard Reset ile snapshot'tan başlat (ilk kurulumda zorunlu)
bash /opt/monad/scripts/reset-workspace.sh

# Mainnet snapshot'ını indir
MF_BUCKET=[https://bucket.monadinfra.com](https://bucket.monadinfra.com)
curl -sSL $MF_BUCKET/scripts/mainnet/restore-from-snapshot.sh | bash

# Forkpoint ve validators getir
VALIDATORS_FILE=/home/monad/monad-bft/config/validators/validators.toml
curl -sSL $MF_BUCKET/scripts/mainnet/download-forkpoint.sh | bash
curl $MF_BUCKET/validators/mainnet/validators.toml -o $VALIDATORS_FILE
chown monad:monad $VALIDATORS_FILE

# Servisleri başlat
systemctl start monad-bft monad-execution monad-rpc
```

# 15. İzleme ve Durum Kontrolü
monad-status Kurulumu:

```Bash
curl -sSL [https://bucket.monadinfra.com/scripts/monad-status.sh](https://bucket.monadinfra.com/scripts/monad-status.sh) -o /usr/local/bin/monad-status
chmod +x /usr/local/bin/monad-status
monad-status
```
Canlı Loglar:

```Bash
journalctl -u monad-bft -f
journalctl -u monad-execution -f
```
BFT Log Analizi (Monlog):

```Bash
usermod -a -G systemd-journal monad
su - monad
curl -sSL [https://pub-b0d0d7272c994851b4c8af22a766f571.r2.dev/scripts/monlog](https://pub-b0d0d7272c994851b4c8af22a766f571.r2.dev/scripts/monlog) -O
chmod u+x ./monlog
./monlog
```

# 16. Validator Kurulumu
Full node tamamen senkronize olduktan sonra validator yapılandırmasına geçilebilir. node.toml içindeki beneficiary ve node_name ayarlarınızı güncelledikten sonra staking precompile üzerinden kayıt yaptırın.

# 17. Node Kurtarma Yöntemleri
YöntemHızNe Zaman KullanılırSoft ResetHızlıNode ucu ağa yakın, kısa süreli kesintiHard ResetOrtaNode ucu ağdan geride, uzun süreli kesinti

Soft Reset (Otomatik – v0.12.1+):

```Bash
systemctl restart monad-bft monad-execution monad-rpc
```

# 18. Node Migrasyonu (Full Node → Validator)
Mevcut full node dosyalarını (node.toml, id-secp, id-bls) yedekleyip validator anahtarlarını taşıyın. İmza üretip yapılandırmayı güncelledikten sonra servisleri yeniden başlatın:

```Bash
systemctl stop monad-bft monad-rpc monad-execution
sleep 1
systemctl start monad-bft monad-rpc monad-execution

# 19. Key Yedekleme ve Geri Yükleme
Geri yükleme örneği:

```Bash
monad-keystore import \
  --ikm "$SECP_IKM" \
  --password "$KEYSTORE_PASSWORD" \
  --keystore-path /home/monad/monad-bft/config/id-secp \
  --key-type secp

# 20. Servis Referansı
ServisAçıklamamonad-bftKonsensüs istemcisimonad-executionExecution istemcisimonad-rpcRPC sunucusu (port 8080)monad-mptTrieDB disk başlatmamonad-cruftSaatlik temizlik servisiotelcolOTEL metrik toplayıcı
