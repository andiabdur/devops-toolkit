#!/bin/bash
# ============================================================
# Module: Velero - Restore
# Fungsi: Restore namespace Kubernetes dari Velero backup
# ============================================================
set -e

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Velero Restore"

# ─── Precheck ───
require_command "velero" "Jalankan modules/velero/install.sh terlebih dahulu"
require_command "kubectl"

# ─── Show Available Backups ───
print_section "Available Backups"

velero backup get
echo ""

# ─── Input ───
print_section "Restore Configuration"

read -rp "  Nama BACKUP yang mau direstore: " RESTORE_BACKUP

# Validate backup exists
if ! velero backup describe "${RESTORE_BACKUP}" &>/dev/null; then
  log_error "Backup '${RESTORE_BACKUP}' tidak ditemukan!"
  exit 1
fi

read -rp "  Restore ke namespace baru? (y/n): " RESTORE_NEW_NS

TIMESTAMP=$(timestamp)

# ─── Execute Restore ───
print_section "Executing Restore"

if [[ "$RESTORE_NEW_NS" == "y" ]]; then
  read -rp "  Nama namespace asal: " SRC_NS
  read -rp "  Nama namespace baru (target): " TARGET_NS

  RESTORE_NAME="restore-${RESTORE_BACKUP}-${TIMESTAMP}"

  log_info "Restore '${RESTORE_BACKUP}' → namespace '${SRC_NS}' ke '${TARGET_NS}'"

  velero restore create "${RESTORE_NAME}" \
    --from-backup "${RESTORE_BACKUP}" \
    --include-namespaces "${SRC_NS}" \
    --namespace-mappings "${SRC_NS}=${TARGET_NS}" \
    --wait
else
  RESTORE_NAME="restore-${RESTORE_BACKUP}-${TIMESTAMP}"

  log_info "Restore '${RESTORE_BACKUP}' ke namespace ASLI"

  velero restore create "${RESTORE_NAME}" \
    --from-backup "${RESTORE_BACKUP}" \
    --wait
fi

echo ""
log_ok "🎉 RESTORE SELESAI!"
echo ""
velero restore get
