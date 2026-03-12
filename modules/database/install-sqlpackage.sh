#!/bin/bash
# ============================================================
# Module: Database - Install sqlpackage (SQL Server DAC Utility)
# Fungsi: Install sqlpackage di Linux (Ubuntu/Debian)
# Ref   : https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-download
# ============================================================

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Install sqlpackage"

# ─── 1. Check OS ───
print_section "Checking System"

if ! command -v apt-get &>/dev/null; then
  log_error "Script ini hanya mendukung Ubuntu/Debian (apt-get)."
  exit 1
fi

log_ok "apt-get ditemukan. Sistem compatible."

# ─── 2. Configuration ───
print_section "Configuration"

INSTALL_DIR="/opt/sqlpackage"
DOWNLOAD_URL="https://aka.ms/sqlpackage-linux"

log_info "Install directory : $INSTALL_DIR"
log_info "Download URL       : $DOWNLOAD_URL (Microsoft latest redirect)"
echo ""

if ! confirm "Lanjutkan instalasi sqlpackage?"; then
  log_info "Dibatalkan."
  exit 0
fi

# ─── 3. Update & Install Dependencies ───
print_section "Installing Dependencies"

log_info "Update apt dan install dependencies..."
sudo apt-get update -yqq

# Auto-detect versi libicu yang tersedia
LIBICU_PKG=""
for pkg in libicu72 libicu70 libicu67 libicu66 libicu60 libicu-dev; do
  if apt-cache show "$pkg" &>/dev/null 2>&1; then
    LIBICU_PKG="$pkg"
    break
  fi
done

if [[ -n "$LIBICU_PKG" ]]; then
  log_info "Menginstall libicu: $LIBICU_PKG"
  sudo apt-get install -yqq unzip libunwind8 "$LIBICU_PKG"
else
  log_warn "libicu tidak ditemukan via auto-detect, mencoba libicu-dev sebagai fallback..."
  sudo apt-get install -yqq unzip libunwind8 libicu-dev
fi

log_ok "Dependencies terinstall."

# ─── 4. Download sqlpackage ───
print_section "Downloading sqlpackage"

log_info "Mendownload dari: $DOWNLOAD_URL"
curl -fsSL "$DOWNLOAD_URL" -o /tmp/sqlpackage.zip || {
  log_error "Gagal mendownload sqlpackage. Cek koneksi internet kamu."
  exit 1
}
log_ok "Download selesai."

# ─── 5. Extract ───
print_section "Extracting"

log_info "Membuat directory $INSTALL_DIR ..."
sudo mkdir -p "$INSTALL_DIR"

log_info "Extracting sqlpackage..."
sudo unzip -o /tmp/sqlpackage.zip -d "$INSTALL_DIR" | tail -5
rm -f /tmp/sqlpackage.zip

log_ok "Extract selesai."

# ─── 6. Set Permissions ───
print_section "Setting Permissions"

sudo chmod a+x "$INSTALL_DIR/sqlpackage"
log_ok "Permission sqlpackage set (a+x)."

# ─── 7. Add to PATH ───
print_section "PATH Setup"

if ! grep -q "$INSTALL_DIR" /etc/profile 2>/dev/null; then
  echo "export PATH=\$PATH:$INSTALL_DIR" | sudo tee -a /etc/profile > /dev/null
  log_ok "$INSTALL_DIR ditambahkan ke /etc/profile"
else
  log_info "$INSTALL_DIR sudah ada di /etc/profile, skip."
fi

export PATH=$PATH:$INSTALL_DIR

# ─── 8. Verify ───
print_section "Verifying Installation"

if "$INSTALL_DIR/sqlpackage" /? &>/dev/null; then
  log_ok "🎉 sqlpackage terinstall dan berjalan dengan baik!"
else
  log_warn "sqlpackage terinstall tapi verifikasi gagal. Coba restart shell dan jalankan: sqlpackage /?"
fi

echo ""
log_ok "Instalasi selesai!"
log_info "Untuk langsung menggunakan di sesi ini:"
echo "    export PATH=\$PATH:$INSTALL_DIR"
log_info "Atau restart shell untuk load dari /etc/profile secara otomatis."
echo ""
