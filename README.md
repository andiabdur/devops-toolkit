# 🛠️ DevOps Toolkit

> **Satu repo untuk semua automation script DevOps kamu.**  
> Clone sekali, langsung bisa pakai untuk setup Kubernetes, backup, restore, dan provisioning server.

---

## 📋 Daftar Isi

- [Fitur](#-fitur)
- [Struktur Repo](#-struktur-repo)
- [Quick Start](#-quick-start)
- [Cara Pakai](#-cara-pakai)
  - [Menu Interaktif](#1-menu-interaktif-paling-gampang)
  - [Jalankan Module Langsung](#2-jalankan-module-langsung)
  - [One-liner dari Server](#3-one-liner-dari-server-tanpa-clone)
- [Module Details](#-module-details)
- [Menambah Module Baru](#-menambah-module-baru)
- [Shared Libraries](#-shared-libraries)
- [Requirements](#-requirements)

---

## ✨ Fitur

| Module | Fungsi |
|--------|--------|
| 🐳 **Kubernetes Setup** | Install Kubernetes cluster via KubeKey (interaktif, multi-node) |
| 📊 **KubeSphere** | Install KubeSphere Dashboard v4.1.3 via Helm |
| 💾 **Velero Backup** | Backup & restore namespace Kubernetes via Velero + MinIO |
| 📦 **Server Backup** | Backup konfigurasi server Linux ke MinIO Object Storage |
| 🖥️ **Provisioning** | Setup server baru (user devops, SSH keys, sudoers, timezone) |
| ☁️ **Azure DevOps** | Install Azure DevOps Self-Hosted Agent (Auto-Versioning) |
| 🛢️ **Database** | Aktivasi SQL Server Agent (2017+) pada Linux |
| 🔄 **MinIO Transfer** | Interactive File/Folder Transfer (Upload, Download, Sync) |

**Bonus:**
- 🎨 Output berwarna dan rapi (logging terstruktur)
- 🔒 Credential file otomatis dihapus setelah selesai (secure)
- 📚 Shared library → tidak ada kode duplikat
- 🔌 Modular → mudah tambah module baru

---

## 📁 Struktur Repo

```
devops-toolkit/
├── toolkit.sh                         # 🎯 Menu utama (entry point)
├── lib/                               # 📚 Shared libraries
│   ├── common.sh                      #   Colors, logging, validasi, utilities
│   ├── minio.sh                       #   MinIO client helper
│   └── ssh.sh                         #   SSH helper (key + password)
│
├── modules/                           # 🔧 Automation modules
│   ├── kubernetes/
│   │   ├── install-kubekey.sh         #   Setup K8s cluster
│   │   └── install-kubesphere.sh      #   Install KubeSphere
│   │
│   ├── velero/
│   │   ├── install.sh                 #   Install/patch Velero + backup
│   │   ├── backup.sh                  #   Backup only
│   │   └── restore.sh                 #   Restore namespace
│   │
│   ├── backup-server/
│   │   ├── backup.sh                  #   Backup config → MinIO
│   │   └── restore.sh                 #   Restore config ← MinIO
│   │
│   ├── provisioning/
│   │   ├── provisioning.sh            #   Setup server baru
│   │   └── servers.txt.example        #   Template server list
│   │
│   ├── azure/
│   │   └── install-agent.sh           #   Install Azure DevOps Agent
│   │
│   ├── database/
│   │   └── enable-sql-agent.sh        #   Enable SQL Server Agent
│   │
│   └── minio/
│       └── transfer.sh                #   Interactive upload/download
```

---

## 🚀 Quick Start

### Clone Repo

```bash
git clone git@github.com:andiabdur/devops-toolkit.git
cd devops-toolkit
```

### Jalankan Menu

```bash
bash toolkit.sh
```

Kamu akan melihat menu interaktif seperti ini:

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   🛠️   DevOps Toolkit v1.0                               ║
║   Your all-in-one DevOps automation scripts              ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  KUBERNETES                                              ║
║    1)  Setup Kubernetes Cluster (KubeKey)                 ║
║    2)  Install KubeSphere Dashboard                       ║
║                                                          ║
║  VELERO BACKUP                                           ║
║    3)  Install Velero + Backup                            ║
║    4)  Backup Only (Velero sudah ada)                     ║
║    5)  Restore Namespace                                  ║
║                                                          ║
║  SERVER BACKUP                                           ║
║    6)  Backup Server Config → MinIO                       ║
║    7)  Restore Server Config ← MinIO                      ║
║                                                          ║
║  PROVISIONING                                            ║
║    8)  Provisioning Server Baru                           ║
║                                                          ║
║  AZURE DEVOPS                                            ║
║    9)  Install Azure DevOps Agent                         ║
║                                                          ║
║  DATABASE                                                ║
║    11) Enable SQL Server Agent                            ║
║                                                          ║
║  TOOLS                                                   ║
║    12) MinIO Transfer (Upload/Download)                   ║
║                                                          ║
║    0)  Exit                                               ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📖 Cara Pakai

### 1. Menu Interaktif (Paling Gampang)

```bash
cd devops-toolkit
bash toolkit.sh
```

### 2. Jalankan Module Langsung

```bash
# Contoh: Install Azure DevOps Agent
bash modules/azure/install-agent.sh
```

---

## 📝 Module Details

### 1️⃣ Kubernetes Setup (KubeKey)
Install Kubernetes cluster menggunakan KubeKey (v1.33.1 dll). Mendukung auth Password dan SSH Key.

### 2️⃣ KubeSphere Dashboard
Install KubeSphere v4.1.3 via Helm.

### 3️⃣ Velero Backup & Restore
Backup & restore namespace Kubernetes via Velero + MinIO S3.

### 4️⃣ Server Config Backup
Backup konfigurasi server (`/home/devops`, `/etc/hosts`, dll) ke MinIO.

### 5️⃣ Server Provisioning
Setup server baru secara batch (user devops, sudoers, ssh keys, timezone).

### 6️⃣ Azure DevOps Agent
Install Azure DevOps Self-Hosted Agent dengan fitur **Auto-Version Discovery** dan **Auto-Service Setup**.

### 7️⃣ Database Helpers
Aktivasi **SQL Server Agent** (2017+) pada Linux tanpa paket tambahan.

### 8️⃣ MinIO Transfer (mc-client)
Transfer file/folder interaktif (Upload, Download, Sync) antara Local dan MinIO.

---

## 📝 Changelog
- ✅ Shared library → eliminasi kode duplikat
- ✅ KubeKey support SSH Key auth
- ✅ **New Module**: Azure DevOps Agent Installer
- ✅ **New Module**: SQL Server Agent Enabler
- ✅ **New Module**: MinIO Transfer Tool
- ✅ Auto-detect architecture untuk semua downloads

---

## 📄 License
MIT License
