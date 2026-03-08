#!/bin/bash
# ============================================================
# Module: Velero - Backup Only
# Fungsi: Backup namespace Kubernetes via Velero (tanpa install)
# ============================================================
set -e

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Velero Backup"

# ─── Precheck ───
require_command "velero" "Jalankan modules/velero/install.sh terlebih dahulu"
require_command "kubectl"

# ─── Input ───
print_section "Backup Configuration"

read -rp "  Namespace yang mau dibackup (pisahkan koma / ketik all): " INPUT_NS
read -rp "  Nama server ini (contoh: btu-cp-01): " INPUT_HOST

TIMESTAMP=$(timestamp)

# ─── Execute Backup ───
print_section "Executing Backup"

if [[ "$INPUT_NS" == "all" ]]; then
  BACKUP_NAME="backup-all-${INPUT_HOST}-${TIMESTAMP}"
  log_info "Membuat backup SEMUA namespace: ${BACKUP_NAME}"
  velero backup create "${BACKUP_NAME}" --wait
else
  IFS=',' read -ra NS_LIST <<< "$INPUT_NS"

  for NS in "${NS_LIST[@]}"; do
    NS=$(echo "$NS" | xargs)

    # Validate namespace exists
    if ! kubectl get ns "$NS" &>/dev/null; then
      log_warn "Namespace '$NS' tidak ditemukan, skip..."
      continue
    fi

    BACKUP_NAME="backup-${NS}-${INPUT_HOST}-${TIMESTAMP}"
    log_info "Membuat backup namespace: $NS → $BACKUP_NAME"
    velero backup create "${BACKUP_NAME}" \
      --include-namespaces "${NS}" \
      --wait
  done
fi

echo ""
log_ok "🎉 SEMUA BACKUP SELESAI!"
echo ""
velero backup get
