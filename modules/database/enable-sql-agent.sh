#!/bin/bash
# ============================================================
# Module: Database - Enable SQL Server Agent
# Fungsi: Support SQL Server Agent on Linux (2017+)
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Enable SQL Server Agent"

# ─── 1. Check Pre-requisites ───
print_section "Checking SQL Server"

if ! command -v mssql-conf &>/dev/null; then
  log_error "mssql-server tidak ditemukan di server ini."
  log_info "Pastikan SQL Server sudah terinstall dan folder /opt/mssql ada."
  exit 1
fi

log_ok "SQL Server terdeteksi."

# ─── 2. Informational ───
echo ""
log_info "Note: Untuk SQL Server 2017 (14.x) CU 4 ke atas,"
log_info "      Agent hanya perlu di-enable (tidak perlu install paket terpisah)."
echo ""

if ! confirm_yes "Lanjutkan aktifkan SQL Server Agent?"; then
  log_info "Dibatalkan oleh user."
  exit 0
fi

# ─── 3. Action ───
print_section "Executing Config"

log_info "Setting sqlagent.enabled = true ..."
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true

log_info "Restarting mssql-server service ..."
sudo systemctl restart mssql-server

log_ok "🎉 SQL Server Agent berhasil diaktifkan dan service sudah direstart!"
echo ""
