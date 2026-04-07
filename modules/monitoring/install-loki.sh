#!/bin/bash
# ============================================================
# Module: Monitoring - Install Loki Server
# Fungsi: Install/Update Grafana Loki Server
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Loki Server Installer"

# ─── 0. Prerequisites ───
if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
  log_info "Installing prerequisites (jq, curl)..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -yqq && sudo apt-get install -y jq curl unzip
  elif command -v yum &>/dev/null; then
    sudo yum install -y epel-release && sudo yum install -y jq curl unzip
  fi
fi

# ─── 1. Check Existing ───
print_section "Checking Existing Install"

IS_INSTALLED=false
if command -v loki &>/dev/null; then
  IS_INSTALLED=true
  log_info "Existing Loki installation detected."
else
  log_info "No Loki installation found."
fi

# ─── 2. Discover Latest Version with Asset ───
print_section "Discovering Versions"

log_info "Fetching latest Loki release from GitHub..."
OS_ARCH=$(uname -m)
case "$OS_ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)       ARCH="amd64" ; log_warn "Arsitektur tidak didukung otomatis ($OS_ARCH), menggunakan default amd64" ;;
esac

# Find the latest release that actually contains the loki-linux binary zip asset
LATEST_VERSION=$(curl -s "https://api.github.com/repos/grafana/loki/releases?per_page=10" | \
  jq -r ".[] | select(.assets[].name | contains(\"loki-linux-$ARCH.zip\")) | .tag_name" | \
  head -n 1 | sed 's/^v//')

if [[ -z "$LATEST_VERSION" ]]; then
  LATEST_VERSION="3.0.0"
  log_warn "Gagal mencari versi terbaru dengan binari Loki, menggunakan fallback: $LATEST_VERSION"
else
  log_ok "Versi terbaru dengan biner ditemukan: v$LATEST_VERSION"
fi

# ─── 3. Inpurt Version ───
read -rp "  Versi Loki yang ingin di-install [$LATEST_VERSION]: " LOKI_VERSION
LOKI_VERSION=${LOKI_VERSION:-$LATEST_VERSION}
CLEAN_VER=$(echo "$LOKI_VERSION" | sed 's/^v//')

# ─── 4. Install Binary ───
print_section "Installing Loki Binary"

BINARY_NAME="loki-linux-${ARCH}"
ZIP_NAME="${BINARY_NAME}.zip"
DOWNLOAD_URL="https://github.com/grafana/loki/releases/download/v${CLEAN_VER}/${ZIP_NAME}"
BIN_PATH="/usr/local/bin/loki"

log_step "Downloading $DOWNLOAD_URL ..."
cd /tmp
if ! curl -fSL "$DOWNLOAD_URL" -o "$ZIP_NAME"; then
  log_error "Gagal mendownload Loki v$CLEAN_VER (404). Silakan cek apakah versi tersebut memiliki biner di GitHub Loki Releases."
  exit 1
fi

unzip -o "$ZIP_NAME"
sudo mv "$BINARY_NAME" "$BIN_PATH"
sudo chmod +x "$BIN_PATH"
rm "$ZIP_NAME"
log_ok "Loki binary v$CLEAN_VER terpasang."

# ─── 5. Configuration Setup ───
print_section "Configuration"

CONFIG_DIR="/etc/loki"
CONFIG_FILE="$CONFIG_DIR/loki-config.yml"
DATA_DIR="/tmp/loki"

sudo mkdir -p "$CONFIG_DIR"
sudo mkdir -p "$DATA_DIR"

log_info "Generating $CONFIG_FILE ..."

sudo tee "$CONFIG_FILE" > /dev/null <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /tmp/loki
  storage:
    filesystem:
      chunks_directory: /tmp/loki/chunks
      rules_directory: /tmp/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h

ruler:
  alertmanager_url: http://localhost:9093
EOF

log_ok "Config generated at $CONFIG_FILE"

# ─── 6. Service Setup ───
print_section "Systemd Service"

SERVICE_FILE="/etc/systemd/system/loki.service"

log_info "Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BIN_PATH -config.file=$CONFIG_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable loki
sudo systemctl restart loki

log_ok "Loki server is running"

# ─── 7. Verification ───
print_section "Verification"
sleep 5
if curl -s localhost:3100/ready | grep -q "ready"; then
  log_ok "🎉 Loki Server is READY at http://localhost:3100"
else
  log_error "Loki Server not ready. Check logs: journalctl -u loki -f"
fi

echo ""
