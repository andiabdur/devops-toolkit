#!/bin/bash
# ============================================================
# Module: Backup Server - Backup Config to MinIO
# Fungsi: Backup konfigurasi server Linux ke MinIO
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
source "$SCRIPT_DIR/../../lib/minio.sh"

print_banner "Server Config Backup to MinIO"

# ─── Install MinIO Client ───
ensure_mc_installed

# ─── Input ───
print_section "Backup Configuration"

read -rp "  MinIO alias         : " MINIO_ALIAS
read -rp "  Custom backup name  : " CUSTOM_NAME
read -rp "  MinIO Bucket [bucket-file]: " MINIO_BUCKET
MINIO_BUCKET=${MINIO_BUCKET:-bucket-file}
read -rp "  MinIO Prefix [backup-baremetal]: " MINIO_PREFIX
MINIO_PREFIX=${MINIO_PREFIX:-backup-baremetal}

echo ""
log_info "Paths yang akan dibackup:"
echo "    /home/devops"
echo "    /etc/nginx/nginx.conf (jika ada)"
echo "    /etc/hosts"
echo ""

if [[ -d "/home/devops" ]]; then
  log_info "Sebagai referensi, ini isi folder /home/devops saat ini:"
  # List direktori/folder yang ada (1 level)
  if command -v ls &>/dev/null; then
    ls -1p /home/devops | awk '{print "    - "$1}'
  fi
  echo ""
fi

read -rp "  Exclude folder di /home/devops (comma separated, opsional): " EXCLUDE_INPUT

# ─── Config ───
DATE=$(timestamp)
BACKUP_NAME="${CUSTOM_NAME}-${DATE}.tar.gz"
BACKUP_PATH="/tmp/${BACKUP_NAME}"
MINIO_TARGET="${MINIO_ALIAS}/${MINIO_BUCKET}/${MINIO_PREFIX}"

# ─── Setup MinIO ───
print_section "MinIO Connection"
setup_minio_alias "$MINIO_ALIAS"
ensure_bucket "${MINIO_ALIAS}/${MINIO_BUCKET}"

# ─── Build Exclude Params ───
EXCLUDE_PARAMS=()
if [[ -n "$EXCLUDE_INPUT" ]]; then
  IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_INPUT"
  for dir in "${EXCLUDES[@]}"; do
    dir=$(echo "$dir" | xargs)
    [[ -n "$dir" ]] && EXCLUDE_PARAMS+=( "--exclude=/home/devops/${dir}" )
  done
  log_info "Excluding: ${EXCLUDES[*]}"
fi

# ─── Build file list ───
BACKUP_SOURCES=()
BACKUP_SOURCES+=("/home/devops")

if [[ -f "/etc/nginx/nginx.conf" ]]; then
  BACKUP_SOURCES+=("/etc/nginx/nginx.conf")
else
  log_warn "/etc/nginx/nginx.conf tidak ditemukan, skip"
fi

BACKUP_SOURCES+=("/etc/hosts")

# ─── Create Backup ───
print_section "Creating Backup"

log_info "Creating archive: $BACKUP_NAME"

tar -czf "$BACKUP_PATH" \
  "${EXCLUDE_PARAMS[@]}" \
  "${BACKUP_SOURCES[@]}" 2>/dev/null || {
    log_error "Gagal membuat archive"
    exit 1
  }

BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | awk '{print $1}')
log_ok "Backup created: $BACKUP_PATH ($BACKUP_SIZE)"

# ─── Upload ───
print_section "Upload to MinIO"

minio_upload "$BACKUP_PATH" "${MINIO_TARGET}/"

# ─── Cleanup ───
rm -f "$BACKUP_PATH"
log_ok "Local backup cleaned up"

echo ""
log_ok "🎉 Backup selesai! File tersimpan di: ${MINIO_TARGET}/${BACKUP_NAME}"
