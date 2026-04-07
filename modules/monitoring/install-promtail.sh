#!/bin/bash
# ============================================================
# Module: Monitoring - Install Promtail Log Shipper
# Fungsi: Install/Update Promtail dan config untuk Loki
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Promtail Installer (Loki Client)"

# ─── 1. Check Existing Service ───
print_section "Checking Existing Install"

IS_INSTALLED=false
CURRENT_VER="None"

if command -v promtail &>/dev/null; then
  IS_INSTALLED=true
  # Try to get version from binary, sometimes it's noisy
  CURRENT_VER=$(promtail --version 2>/dev/null | grep 'version' | awk '{print $3}' || echo "Found (unknown version)")
  log_info "Existing Promtail found: v$CURRENT_VER"
else
  log_info "No Promtail installation found."
fi

# ─── 2. Fetch Latest Version with Asset ───
print_section "Discovering Versions"

log_info "Fetching latest Promtail release from GitHub..."
OS_ARCH=$(uname -m)
case "$OS_ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)       ARCH="amd64" ; log_warn "Arsitektur tidak didukung otomatis ($OS_ARCH), menggunakan default amd64" ;;
esac

# Find the latest release that actually contains the promtail-linux binary zip asset
LATEST_VERSION=$(curl -s "https://api.github.com/repos/grafana/loki/releases?per_page=20" | \
  jq -r ".[] | select(.assets[].name | contains(\"promtail-linux-$ARCH.zip\")) | .tag_name" | \
  head -n 1 | sed 's/^v//')

if [[ -z "$LATEST_VERSION" ]]; then
  LATEST_VERSION="3.6.10" # Fallback stable with asset
  log_warn "Gagal mencari versi terbaru dengan binari Promtail, menggunakan fallback: $LATEST_VERSION"
else
  log_ok "Versi terbaru dengan biner ditemukan: v$LATEST_VERSION"
fi

# ─── 3. Installation Flow ───
DO_UPGRADE=true

if [[ "$IS_INSTALLED" == "true" ]]; then
  echo ""
  log_info "Promtail sudah terinstall."
  echo "  1) Update/Install Biner Baru + Update Konfigurasi"
  echo "  2) Gunakan Biner Existing + Update Konfigurasi Saja"
  read -rp "  Pilih opsi [1/2]: " -n 1 -r OPSI
  echo ""
  
  if [[ "$OPSI" == "2" ]]; then
    DO_UPGRADE=false
    log_info "Opsi dipilih: Update Konfigurasi Saja."
  else
    log_info "Opsi dipilih: Update Biner + Konfigurasi."
  fi
fi

if [[ "$DO_UPGRADE" == "true" ]]; then
  read -rp "  Masukkan versi Promtail yang mau di-install [$LATEST_VERSION]: " PROM_VERSION
  PROM_VERSION=${PROM_VERSION:-$LATEST_VERSION}
  # Remove leading 'v'
  CLEAN_VERSION=$(echo "$PROM_VERSION" | sed 's/^v//')

  print_section "Installing Promtail v$CLEAN_VERSION"
  
  # Prerequisites
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -yqq && sudo apt-get install -y unzip curl
  elif command -v yum &>/dev/null; then
    sudo yum install -y unzip curl
  fi

  BINARY_NAME="promtail-linux-${ARCH}"
  ZIP_NAME="${BINARY_NAME}.zip"
  DOWNLOAD_URL="https://github.com/grafana/loki/releases/download/v${CLEAN_VERSION}/${ZIP_NAME}"
  BIN_PATH="/usr/local/bin/promtail"

  log_step "Downloading $DOWNLOAD_URL ..."
  cd /tmp
  if ! curl -fSL "$DOWNLOAD_URL" -o "$ZIP_NAME"; then
    log_error "Gagal mendownload versi $PROM_VERSION (404). Silakan cek apakah versi tersebut memiliki biner di GitHub Loki Releases."
    exit 1
  fi
  
  unzip -o "$ZIP_NAME"
  sudo mv "$BINARY_NAME" "$BIN_PATH"
  sudo chmod +x "$BIN_PATH"
  rm "$ZIP_NAME"
  log_ok "Binary Promtail v$CLEAN_VERSION terpasang."
fi

# ─── 4. Input Detail Loki ───
print_section "Loki Configuration"

read -rp "  Loki Server URL [http://loki.internal:3100/loki/api/v1/push]: " LOKI_URL
LOKI_URL=${LOKI_URL:-http://loki.internal:3100/loki/api/v1/push}

read -rp "  Server Name (Label untuk Grafana) [$(hostname)]: " SERVER_NAME
SERVER_NAME=${SERVER_NAME:-$(hostname)}

# ─── 5. Config Setup ───
CONFIG_DIR="/etc/promtail"
CONFIG_FILE="$CONFIG_DIR/config.yml"
sudo mkdir -p "$CONFIG_DIR"

log_info "Generating $CONFIG_FILE ..."

# Create YAML with the user-provided scrape_config logic
sudo tee "$CONFIG_FILE" > /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: $LOKI_URL

scrape_configs:
  - job_name: nginx_vhost
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx_vhost_logs
          server: "$SERVER_NAME"
          __path__: /var/log/nginx/access-vhost.log

    pipeline_stages:
      - regex:
          expression: '^(?P<host>[^ ]+) (?P<ip>[^ ]+) - (?P<user>[^ ]+) \[(?P<timestamp>[^\]]+)\] "(?P<method>\\S+) (?P<path>\\S+) (?P<http_version>[^"]+)" (?P<status_code>\\d+) (?P<size>\\d+)'
      - labels:
          host:
          status_code:
      - timestamp:
          source: timestamp
          format: '02/Jan/2006:15:04:05 -0700'
EOF

log_ok "Config file generated."

# ─── 6. Service Setup ───
SERVICE_FILE="/etc/systemd/system/promtail.service"

if [[ ! -f "$SERVICE_FILE" || "$DO_UPGRADE" == "true" ]]; then
  log_info "Setting up systemd service..."
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=$CONFIG_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable promtail
fi

log_info "Restarting Promtail service..."
sudo systemctl restart promtail

# ─── 7. Verification ───
print_section "Verifying Connection"

log_info "Waiting for service to stabilize (5s)..."
sleep 5

# Check 1: Target file presence
if [[ ! -f "/var/log/nginx/access-vhost.log" ]]; then
  log_warn "File log /var/log/nginx/access-vhost.log tidak ditemukan!"
  log_info "Pastikan Nginx sudah setup vhost logging ke path tersebut."
else
  log_ok "Log file ditemukan."
fi

# Check 2: Connectivity to Loki
LOKI_BASE=$(echo "$LOKI_URL" | sed 's/\/loki\/api\/v1\/push//')
if curl -s --connect-timeout 5 "$LOKI_BASE/ready" | grep -q "ready"; then
  log_ok "Loki Server is READY"
else
  log_warn "Loki Server tidak merespon /ready."
fi

# Check 3: Journal errors
if sudo journalctl -u promtail -n 30 | grep -qi "error"; then
  log_warn "Ditemukan error pada log Promtail. Cek detail: journalctl -u promtail -f"
else
  log_ok "Tidak ada error kritis di journalctl."
fi

# ─── Summary ───
echo ""
print_section "SUMMARY"
log_ok "🎉 Promtail berhasil di-$(if [[ "$DO_UPGRADE" == "true" ]]; then echo "install/upgrade"; else echo "konfigurasi"; fi)!"
log_info "Loki URL : $LOKI_URL"
log_info "Server   : $SERVER_NAME"
log_info "Query    : {server=\"$SERVER_NAME\", job=\"nginx_vhost_logs\"}"
echo ""
