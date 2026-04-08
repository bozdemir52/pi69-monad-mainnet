# Monad Mainnet Validator OS (v2.0)

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
