#!/bin/bash
# ============================================================
# Module: Backup Server - Restore Config from MinIO
# Fungsi: Restore konfigurasi server Linux dari MinIO
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
source "$SCRIPT_DIR/../../lib/minio.sh"

print_banner "Server Config Restore from MinIO"

# ─── Install MinIO Client ───
ensure_mc_installed

# ─── Input ───
print_section "Restore Configuration"

read -rp "  MinIO alias         : " MINIO_ALIAS
read -rp "  MinIO Bucket [bucket-file]: " MINIO_BUCKET
MINIO_BUCKET=${MINIO_BUCKET:-bucket-file}
read -rp "  MinIO Prefix [backup-baremetal]: " MINIO_PREFIX
MINIO_PREFIX=${MINIO_PREFIX:-backup-baremetal}

# ─── Setup MinIO ───
setup_minio_alias "$MINIO_ALIAS"

# ─── List Available Backups ───
print_section "Available Backups"

SOURCE_DIR="${MINIO_ALIAS}/${MINIO_BUCKET}/${MINIO_PREFIX}/"
log_info "Listing backups in ${SOURCE_DIR}:"
echo ""
"$MC_CMD" ls "$SOURCE_DIR" 2>/dev/null || {
  log_error "Tidak bisa membaca backup list"
  exit 1
}
echo ""

# ─── Select Backup ───
read -rp "  Nama file backup (contoh: server-20260308.tar.gz): " BACKUP_FILE

SOURCE_PATH="${MINIO_ALIAS}/${MINIO_BUCKET}/${MINIO_PREFIX}/${BACKUP_FILE}"
LOCAL_PATH="/tmp/${BACKUP_FILE}"

# ─── Download ───
print_section "Download Backup"
minio_download "$SOURCE_PATH" "$LOCAL_PATH"

# ─── Preview isi backup ───
print_section "Preview Backup Contents"

log_info "Isi backup file (10 entri pertama):"
tar -tzf "$LOCAL_PATH" | head -20
echo "  ..."
echo ""

BACKUP_SIZE=$(du -sh "$LOCAL_PATH" | awk '{print $1}')
log_info "File size: $BACKUP_SIZE"

# ─── Confirm Restore ───
echo ""
echo "  ${RED}${BOLD}⚠️  WARNING${RESET}"
echo "  ${YELLOW}Ini akan EXTRACT backup ke root filesystem (/)${RESET}"
echo "  ${YELLOW}File yang mungkin ter-overwrite:${RESET}"
echo "    - /home/devops"
echo "    - /etc/nginx/nginx.conf"
echo "    - /etc/hosts"
echo ""

if ! confirm_yes "Lanjutkan restore?"; then
  log_info "Restore dibatalkan"
  rm -f "$LOCAL_PATH"
  exit 0
fi

# ─── Restore ───
print_section "Restoring"

log_info "Extracting backup (sudo required)..."
sudo tar -xzp -f "$LOCAL_PATH" -C /

log_ok "Restore completed successfully!"

# ─── Cleanup ───
echo ""
if confirm "Hapus file backup yang sudah didownload?"; then
  rm -f "$LOCAL_PATH"
  log_ok "Local backup file removed"
fi

echo ""
log_ok "🎉 Restore selesai!"
