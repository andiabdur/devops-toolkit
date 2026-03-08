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
  - [Kubernetes Setup](#1%EF%B8%8F⃣-kubernetes-setup-kubekey)
  - [KubeSphere Dashboard](#2%EF%B8%8F⃣-kubesphere-dashboard)
  - [Velero Backup](#3%EF%B8%8F⃣-velero-backup--restore)
  - [Server Config Backup](#4%EF%B8%8F⃣-server-config-backup)
  - [Server Provisioning](#5%EF%B8%8F⃣-server-provisioning)
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
│   └── provisioning/
│       ├── provisioning.sh            #   Setup server baru
│       └── servers.txt.example        #   Template server list
│
├── docs/
│   └── CONTRIBUTING.md                # Cara tambah module baru
├── .gitignore
└── README.md
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
║    0)  Exit                                               ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

Tinggal pilih angka, lalu ikuti instruksi interaktif di layar. **Semudah itu!** 🎉

---

## 📖 Cara Pakai

### 1. Menu Interaktif (Paling Gampang)

```bash
cd devops-toolkit
bash toolkit.sh
```

Pilih nomor menu → ikuti instruksi → selesai. ✅

### 2. Jalankan Module Langsung

Kalau sudah tahu mau jalankan module yang mana, bisa langsung:

```bash
# Setup Kubernetes cluster
bash modules/kubernetes/install-kubekey.sh

# Install KubeSphere Dashboard
bash modules/kubernetes/install-kubesphere.sh

# Install Velero + Backup
bash modules/velero/install.sh

# Backup namespace (Velero sudah ada)
bash modules/velero/backup.sh

# Restore namespace
bash modules/velero/restore.sh

# Backup server config ke MinIO
bash modules/backup-server/backup.sh

# Restore server config dari MinIO
bash modules/backup-server/restore.sh

# Provisioning server baru
cp modules/provisioning/servers.txt.example servers.txt
nano servers.txt  # isi IP server
bash modules/provisioning/provisioning.sh
```

### 3. One-liner dari Server (Tanpa Clone)

Kalau mau jalankan langsung di server tanpa clone repo:

```bash
# Contoh: Setup Kubernetes
curl -sL https://raw.githubusercontent.com/andiabdur/devops-toolkit/main/modules/kubernetes/install-kubekey.sh | bash
```

> ⚠️ **Catatan:** One-liner tidak akan bisa load shared libraries (`lib/`).  
> Untuk fitur lengkap, sebaiknya **clone repo dulu**.

---

## 📝 Module Details

### 1️⃣ Kubernetes Setup (KubeKey)

**Fungsi:** Install Kubernetes cluster menggunakan KubeKey (interaktif, multi-node).

**Cara pakai:**
```bash
bash modules/kubernetes/install-kubekey.sh
```

**Yang ditanya:**
- Versi Kubernetes (contoh: `v1.33.1`)
- Nama file config
- Jumlah node
- **Metode autentikasi SSH:**
  - `1) Password` — akses node pakai user + password
  - `2) SSH Key` — akses node pakai user + private key path
- IP + credentials per node
- Network config (Pod CIDR, Service CIDR, CNI plugin)

**Output:** File config YAML + eksekusi `kk create cluster`

<details>
<summary>📸 Contoh alur (Password mode)</summary>

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Input Config Data
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Versi Kubernetes (contoh: v1.33.1): v1.33.1
  Nama file config: config-production.yaml
  Berapa jumlah node? 3

  Pilih metode autentikasi SSH ke node:
    1) Password
    2) SSH Key (Private Key)
  Pilih [1/2]: 1
  [INFO]  Mode: Password

  Semua node pakai credential sama? (Y/N): Y
    User: ubuntu
    Password: ****

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Input Node Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STEP]  Node ke-1 dari 3
    Name: master-01
    Address (IP): 192.168.1.10
...
```
</details>

<details>
<summary>📸 Contoh alur (SSH Key mode)</summary>

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Input Config Data
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Versi Kubernetes (contoh: v1.33.1): v1.33.1
  Nama file config: config-production.yaml
  Berapa jumlah node? 3

  Pilih metode autentikasi SSH ke node:
    1) Password
    2) SSH Key (Private Key)
  Pilih [1/2]: 2
  [INFO]  Mode: SSH Key

  Semua node pakai credential sama? (Y/N): Y
    User: ubuntu
    Private key path (contoh: ~/.ssh/id_rsa): ~/.ssh/id_rsa

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Input Node Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[STEP]  Node ke-1 dari 3
    Name: master-01
    Address (IP): 192.168.1.10
...
```
</details>

---

### 2️⃣ KubeSphere Dashboard

**Fungsi:** Install KubeSphere v4.1.3 Dashboard via Helm.

**Cara pakai:**
```bash
bash modules/kubernetes/install-kubesphere.sh
```

**Yang ditanya:**
- KubeSphere version (default: v4.1.3)
- Base URL untuk download images
- Helm chart filename

**Default credential setelah install:**
- Username: `admin`
- Password: `P@88w0rd`

> ⚠️ **Segera ganti password default setelah login!**

**Prasyarat:** `helm`, `wget`, `containerd`, cluster Kubernetes sudah running.

---

### 3️⃣ Velero Backup & Restore

Backup & restore Kubernetes namespace menggunakan Velero + MinIO S3.

#### Install Velero + Backup

```bash
bash modules/velero/install.sh
```

**Yang dilakukan:**
1. Auto-install Velero CLI (latest)
2. Detect Velero server (install baru / patch existing)
3. Setup MinIO sebagai backup location
4. Jalankan backup (per-namespace atau semua)

#### Backup Only (Velero sudah ter-install)

```bash
bash modules/velero/backup.sh
```

**Yang ditanya:**
- Namespace yang mau dibackup (pisahkan koma, atau ketik `all`)
- Nama server identifier

#### Restore Namespace

```bash
bash modules/velero/restore.sh
```

**Fitur restore:**
- Lihat daftar backup yang tersedia
- Restore ke namespace asli
- Restore ke namespace **baru** (cocok untuk DR test / cloning)

---

### 4️⃣ Server Config Backup

Backup konfigurasi server Linux ke MinIO Object Storage.

#### Yang Dibackup

| Path | Keterangan |
|------|-----------|
| `/home/devops` | Home directory user devops |
| `/etc/nginx/nginx.conf` | Konfigurasi Nginx (jika ada) |
| `/etc/hosts` | File hosts |

#### Backup

```bash
bash modules/backup-server/backup.sh
```

**Yang ditanya:**
- MinIO alias
- Custom backup name
- Bucket + prefix (default: `bucket-file/backup-baremetal`)
- Folder yang mau di-exclude

#### Restore

```bash
bash modules/backup-server/restore.sh
```

**Fitur:**
- List backup yang tersedia di MinIO
- Preview isi backup sebelum extract
- Konfirmasi sebelum overwrite (safety) 

---

### 5️⃣ Server Provisioning

Setup server baru secara batch (banyak server sekaligus).

**Yang dilakukan di setiap server:**
- ✅ Setup SSH config (key + password auth)
- ✅ Create user `devops` (jika belum ada)
- ✅ Setup sudoers NOPASSWD
- ✅ Inject SSH public key
- ✅ Set timezone (default: Asia/Jakarta)
- ✅ Smart SSH: coba key dulu, fallback ke password
- ✅ Idempotent (aman dijalankan berulang)

**Cara pakai:**

```bash
# 1. Buat file server list
cp modules/provisioning/servers.txt.example servers.txt
nano servers.txt

# Isi dengan IP server (satu per baris):
# 192.168.1.10
# 192.168.1.11
# 192.168.1.12

# 2. Jalankan
bash modules/provisioning/provisioning.sh
# atau
bash modules/provisioning/provisioning.sh /path/to/custom-servers.txt
```

**Yang ditanya:**
- SSH user awal (default: `ubuntu`)
- SSH key path
- Password fallback
- Password user devops
- Public key untuk user devops

**Output akhir:**
```
━━━━━━━━━━━━━━━━━━━━━━
  Summary
━━━━━━━━━━━━━━━━━━━━━━
[OK]    Success: 3 server
[ERROR] Failed: 0 server
```

---

## 🔌 Menambah Module Baru

Mau nambahin automation script lain? Gampang banget:

### Step 1: Buat folder

```bash
mkdir -p modules/nama-module-kamu
```

### Step 2: Buat script

```bash
#!/bin/bash
set -e

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
# source "$SCRIPT_DIR/../../lib/minio.sh"   # kalau butuh MinIO
# source "$SCRIPT_DIR/../../lib/ssh.sh"     # kalau butuh SSH

print_banner "Nama Module Kamu"

# ... logic kamu di sini ...

log_ok "Selesai!"
```

### Step 3: Update menu di `toolkit.sh`

Tambah opsi baru di fungsi `show_menu()` dan di `case` statement.

### Step 4: Commit & push!

```bash
git add .
git commit -m "feat: add nama-module"
git push
```

📖 Panduan lengkap: [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)

---

## 📚 Shared Libraries

Semua module bisa menggunakan fungsi dari shared libraries berikut:

### `lib/common.sh` — Utilities Umum

| Fungsi | Kegunaan |
|--------|----------|
| `log_info "msg"` | Log info (cyan) |
| `log_ok "msg"` | Log sukses (green) |
| `log_warn "msg"` | Log warning (yellow) |
| `log_error "msg"` | Log error (red) |
| `log_step "msg"` | Log step (blue) |
| `print_banner "title"` | Banner besar |
| `print_section "title"` | Section divider |
| `validate_ip "1.2.3.4"` | Validasi IP address (return 0/1) |
| `require_command "cmd"` | Cek command ada, exit jika tidak |
| `confirm "message"` | Konfirmasi y/n |
| `confirm_yes "message"` | Konfirmasi yes/no (explicit) |
| `countdown 5` | Countdown timer |
| `timestamp` | Format: YYYYMMDD |
| `timestamp_full` | Format: YYYYMMDD-HHMMSS |

### `lib/minio.sh` — MinIO Helper

| Fungsi | Kegunaan |
|--------|----------|
| `ensure_mc_installed` | Auto-install MinIO Client (mc) |
| `setup_minio_alias "alias"` | Setup/validate MinIO alias |
| `ensure_bucket "alias/bucket"` | Pastikan bucket ada |
| `minio_upload "file" "target"` | Upload file ke MinIO |
| `minio_download "source" "local"` | Download file dari MinIO |

### `lib/ssh.sh` — SSH Helper

| Fungsi | Kegunaan |
|--------|----------|
| `test_ssh_key "user" "host" "key"` | Test SSH key login |
| `ssh_exec_key "user" "host" "key" "cmd"` | Exec via SSH key |
| `ssh_exec_pass "user" "host" "pass" "cmd"` | Exec via password |
| `ssh_smart_exec "user" "host" "key" "pass" "cmd"` | Auto: key dulu, fallback password |

---

## 📋 Requirements

### Minimum (Semua Module)

- Linux (Ubuntu/Debian/CentOS/RHEL)
- Bash 4+
- `curl`, `wget`

### Per-Module

| Module | Requirements |
|--------|-------------|
| Kubernetes Setup | (akan download KubeKey otomatis) |
| KubeSphere | `helm`, `containerd`, K8s cluster running |
| Velero | `kubectl` terkonfigurasi ke cluster |
| Server Backup | `sudo`, akses MinIO endpoint |
| Provisioning | `sshpass` (untuk fallback), SSH access ke target server |

---

## 📝 Changelog

Repo ini merupakan konsolidasi dari 4 repo terpisah:

| Repo Lama | Module Baru |
|-----------|-------------|
| [Kubesphare-v4.1.3](https://github.com/config-devops/Kubesphare-v4.1.3) | `modules/kubernetes/` |
| [velero-backup](https://github.com/config-devops/velero-backup) | `modules/velero/` |
| [backup-config](https://github.com/config-devops/backup-config) | `modules/backup-server/` |
| [provisioning-server](https://github.com/config-devops/provisioning-server) | `modules/provisioning/` |

### Perbaikan yang dilakukan:

- ✅ Shared library → eliminasi kode duplikat
- ✅ Credential file menggunakan temp file + auto-cleanup (`trap`)
- ✅ Semua script punya shebang (`#!/bin/bash`) dan `set -e`
- ✅ KubeKey: support SSH Key auth (selain password)
- ✅ Validasi namespace sebelum backup Velero
- ✅ Preview backup sebelum restore (server config)
- ✅ Menghilangkan `eval` berbahaya di provisioning
- ✅ Configurable parameter (tidak hardcoded)
- ✅ Auto-detect architecture untuk MinIO Client
- ✅ Timezone menggunakan `timedatectl` jika tersedia
- ✅ Typo fix: "Valero" → "Velero"
- ✅ Timestamp konsisten (YYYYMMDD)

---

## 📄 License

MIT License - Feel free to use and modify.

---

<div align="center">

**Made with ❤️ for DevOps Engineers**

</div>
