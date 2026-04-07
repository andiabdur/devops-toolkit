#!/bin/bash
# ============================================================
# Module: Monitoring - Install Prometheus Server
# Fungsi: Install/Update Prometheus Server
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Prometheus Server Installer"

# ─── 0. Prerequisites ───
if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
  log_info "Installing prerequisites (jq, curl, tar)..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -yqq && sudo apt-get install -y jq curl tar
  elif command -v yum &>/dev/null; then
    sudo yum install -y epel-release && sudo yum install -y jq curl tar
  fi
fi

# ─── 1. Check Existing ───
print_section "Checking Existing Install"

IS_INSTALLED=false
if command -v prometheus &>/dev/null; then
  IS_INSTALLED=true
  CURRENT_VER=$(prometheus --version 2>&1 | grep 'version' | awk '{print $3}')
  log_info "Existing Prometheus found: v$CURRENT_VER"
else
  log_info "No Prometheus installation found."
fi

# ─── 2. Fetch Latest Version ───
print_section "Discovering Versions"

OS_ARCH=$(uname -m)
case "$OS_ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)       ARCH="amd64" ; log_warn "Arsitektur tidak didukung otomatis ($OS_ARCH), menggunakan default amd64" ;;
esac

LATEST_VERSION=$(curl -s "https://api.github.com/repos/prometheus/prometheus/releases/latest" | jq -r .tag_name | sed 's/^v//')
log_ok "Versi terbaru ditemukan: v$LATEST_VERSION"

# ─── 3. Installation Flow ───
DO_INSTALL=true
if [[ "$IS_INSTALLED" == "true" ]]; then
  read -rp "Prometheus sudah ada. Upgrade ke v$LATEST_VERSION? (y/n): " -n 1 -r CONF
  echo ""
  [[ ! "$CONF" =~ ^[Yy]$ ]] && DO_INSTALL=false
fi

if [[ "$DO_INSTALL" == "true" ]]; then
  read -rp "Masukkan versi yang diinginkan [$LATEST_VERSION]: " PROM_VERSION
  PROM_VERSION=${PROM_VERSION:-$LATEST_VERSION}
  CLEAN_VER=$(echo "$PROM_VERSION" | sed 's/^v//')

  TAR_NAME="prometheus-${CLEAN_VER}.linux-${ARCH}.tar.gz"
  DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${CLEAN_VER}/${TAR_NAME}"
  
  log_step "Downloading $DOWNLOAD_URL ..."
  cd /tmp
  if ! curl -fSL "$DOWNLOAD_URL" -o "$TAR_NAME"; then
    log_error "Gagal mendownload Prometheus v$CLEAN_VER. Cek versi di GitHub."
    exit 1
  fi

  tar xvf "$TAR_NAME"
  cd "prometheus-${CLEAN_VER}.linux-${ARCH}"
  
  # Binaries
  sudo mv prometheus /usr/local/bin/
  sudo mv promtool /usr/local/bin/
  sudo chmod +x /usr/local/bin/prometheus /usr/local/bin/promtool

  # Config and Data Dirs
  sudo mkdir -p /etc/prometheus /var/lib/prometheus
  sudo mv consoles console_libraries /etc/prometheus/
  
  # Initial Config
  if [[ ! -f "/etc/prometheus/prometheus.yml" ]]; then
    sudo mv prometheus.yml /etc/prometheus/
  fi

  cd /tmp
  rm -rf "prometheus-${CLEAN_VER}.linux-${ARCH}" "$TAR_NAME"
  log_ok "Prometheus binary v$CLEAN_VER terpasang."
fi

# ─── 4. Service Setup ───
print_section "Systemd Service"

SERVICE_FILE="/etc/systemd/system/prometheus.service"
if [[ ! -f "$SERVICE_FILE" ]]; then
  log_info "Creating systemd service..."
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable prometheus
fi

log_info "Restarting Prometheus..."
sudo systemctl restart prometheus

# ─── 5. Verification ───
print_section "Verification"
sleep 2
if curl -s localhost:9090/-/ready | grep -q "ready"; then
  log_ok "🎉 Prometheus is READY at http://localhost:9090"
else
  log_error "Prometheus not ready. Check: journalctl -u prometheus -f"
fi

echo ""
