# Cara Menambah Module Baru

Panduan untuk menambahkan module/script baru ke DevOps Toolkit.

## Langkah-Langkah

### 1. Buat Folder Module

```bash
mkdir -p modules/nama-module
```

### 2. Buat Script

```bash
cat > modules/nama-module/script.sh << 'HEREDOC'
#!/bin/bash
set -e

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
# source "$SCRIPT_DIR/../../lib/minio.sh"   # jika butuh MinIO
# source "$SCRIPT_DIR/../../lib/ssh.sh"     # jika butuh SSH

print_banner "Nama Module Kamu"

# ... logic kamu di sini ...

log_ok "Selesai!"
HEREDOC

chmod +x modules/nama-module/script.sh
```

### 3. Update Menu di `toolkit.sh`

Tambahkan opsi baru di menu `show_menu()` dan di `case` statement.

### 4. (Opsional) Buat README

```bash
cat > modules/nama-module/README.md << 'EOF'
# Nama Module

Deskripsi singkat module ini.

## Cara Pakai
...

## Requirement
...
EOF
```

## Shared Libraries yang Tersedia

| Library | File | Fungsi |
|---------|------|--------|
| Common | `lib/common.sh` | Colors, logging, validation IP, confirm, countdown, timestamp |
| MinIO | `lib/minio.sh` | Install mc, setup alias, ensure bucket, upload, download |
| SSH | `lib/ssh.sh` | SSH key test, exec key, exec password, smart exec |

## Conventions

- Setiap script harus dimulai dengan `#!/bin/bash` dan `set -e`
- Selalu load `lib/common.sh` sebagai minimum
- Gunakan fungsi dari shared library, jangan duplikasi
- Gunakan `print_banner`, `print_section`, `log_*` untuk output yang konsisten
- Gunakan `require_command` untuk cek dependency
