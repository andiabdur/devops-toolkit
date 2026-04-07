#!/bin/bash
# ============================================================
# Module: Monitoring - Install Node Exporter
# Fungsi: Install/Update Prometheus Node Exporter
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Node Exporter Installer"

# ─── 0. Prerequisites ───
if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
  log_info "Installing prerequisites (jq, curl)..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -yqq && sudo apt-get install -y jq curl tar
  elif command -v yum &>/dev/null; then
    sudo yum install -y epel-release && sudo yum install -y jq curl tar
  fi
fi

# ─── 1. Check Existing ───
print_section "Checking Existing Install"

IS_INSTALLED=false
if command -v node_exporter &>/dev/null; then
  IS_INSTALLED=true
  CURRENT_VER=$(node_exporter --version 2>&1 | grep 'version' | awk '{print $3}')
  log_info "Existing Node Exporter found: v$CURRENT_VER"
else
  log_info "No Node Exporter installation found."
fi

# ─── 2. Fetch Latest Version ───
print_section "Discovering Versions"

OS_ARCH=$(uname -m)
case "$OS_ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)       ARCH="amd64" ; log_warn "Arsitektur tidak didukung otomatis ($OS_ARCH), menggunakan default amd64" ;;
esac

log_info "Mencari versi terbaru Node Exporter..."
LATEST_VERSION=$(curl -sL "https://api.github.com/repos/prometheus/node_exporter/releases/latest" | jq -r .tag_name | sed 's/^v//')

if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "null" ]]; then
  LATEST_VERSION="1.7.0" # Fallback stable
  log_warn "Gagal mencari versi via GitHub API. Menggunakan fallback: $LATEST_VERSION"
else
  log_ok "Versi terbaru ditemukan: v$LATEST_VERSION"
fi

# ─── 3. Installation Flow ───
DO_INSTALL=true
if [[ "$IS_INSTALLED" == "true" ]]; then
  read -rp "Node Exporter sudah ada. Upgrade ke v$LATEST_VERSION? (y/n): " -n 1 -r CONF
  echo ""
  [[ ! "$CONF" =~ ^[Yy]$ ]] && DO_INSTALL=false
fi

if [[ "$DO_INSTALL" == "true" ]]; then
  read -rp "Masukkan versi yang diinginkan [$LATEST_VERSION]: " PROM_VERSION
  PROM_VERSION=${PROM_VERSION:-$LATEST_VERSION}
  CLEAN_VER=$(echo "$PROM_VERSION" | sed 's/^v//')

  TAR_NAME="node_exporter-${CLEAN_VER}.linux-${ARCH}.tar.gz"
  DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${CLEAN_VER}/${TAR_NAME}"
  
  log_step "Downloading $DOWNLOAD_URL ..."
  cd /tmp
  if ! curl -fSL "$DOWNLOAD_URL" -o "$TAR_NAME"; then
    log_error "Gagal mendownload Node Exporter v$PROM_VERSION. Cek versi di GitHub."
    exit 1
  fi

  tar xvf "$TAR_NAME"
  sudo mv "node_exporter-${CLEAN_VER}.linux-${ARCH}/node_exporter" "/usr/local/bin/"
  sudo chmod +x "/usr/local/bin/node_exporter"
  rm -rf "node_exporter-${CLEAN_VER}.linux-${ARCH}" "$TAR_NAME"
  log_ok "Node Exporter binary v$CLEAN_VER terpasang."
fi

# ─── 4. Service Setup ───
print_section "Systemd Service"

SERVICE_FILE="/etc/systemd/system/node_exporter.service"
if [[ ! -f "$SERVICE_FILE" ]]; then
  log_info "Creating systemd service..."
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable node_exporter
fi

log_info "Restarting Node Exporter..."
sudo systemctl restart node_exporter

# ─── 5. Verification ───
print_section "Verification"
sleep 2
if curl -s localhost:9100/metrics | grep -q "node_"; then
  log_ok "🎉 Node Exporter is running at http://localhost:9100/metrics"
else
  log_error "Node Exporter not responding. Check: journalctl -u node_exporter -f"
fi

echo ""
