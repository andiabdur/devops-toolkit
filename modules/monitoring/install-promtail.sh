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

# ─── 1. Discover Latest Version ───
print_section "Checking Latest Promtail Version"

log_info "Fetching latest version from GitHub..."
OS_ARCH=$(uname -m)
case "$OS_ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)       ARCH="amd64" ; log_warn "Arsitektur tidak didukung otomatis ($OS_ARCH), menggunakan default amd64" ;;
esac

# Get latest release from grafana/loki
LATEST_VERSION=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

if [[ -z "$LATEST_VERSION" ]]; then
  LATEST_VERSION="3.0.0" # Fallback
  log_warn "Gagal mendapatkan versi terbaru dari GitHub API, menggunakan fallback: $LATEST_VERSION"
else
  log_ok "Versi terbaru ditemukan: v$LATEST_VERSION"
fi

# ─── 2. Input Configuration ───
print_section "Configuration"

read -rp "  Loki Server URL [http://loki.internal:3100/loki/api/v1/push]: " LOKI_URL
LOKI_URL=${LOKI_URL:-http://loki.internal:3100/loki/api/v1/push}

read -rp "  Promtail Version [$LATEST_VERSION]: " PROM_VERSION
PROM_VERSION=${PROM_VERSION:-$LATEST_VERSION}

read -rp "  Server Name (Label) [$(hostname)]: " SERVER_NAME
SERVER_NAME=${SERVER_NAME:-$(hostname)}

# Remove leading 'v' if present for download URL
CLEAN_VERSION=$(echo "$PROM_VERSION" | sed 's/^v//')

# ─── 3. Check Prerequisites ───
print_section "Prerequisites"
log_info "Installing unzip..."
if command -v apt-get &>/dev/null; then
  sudo apt-get update -yqq && sudo apt-get install -y unzip curl
elif command -v yum &>/dev/null; then
  sudo yum install -y unzip curl
fi

# ─── 4. Install / Update Binary ───
print_section "Installing Promtail Binary"

BINARY_NAME="promtail-linux-${ARCH}"
ZIP_NAME="${BINARY_NAME}.zip"
DOWNLOAD_URL="https://github.com/grafana/loki/releases/download/v${CLEAN_VERSION}/${ZIP_NAME}"

# Install path
BIN_PATH="/usr/local/bin/promtail"

if command -v promtail &>/dev/null; then
  CURRENT_VER=$(promtail --version | grep 'version' | awk '{print $3}')
  log_info "Existing promtail found: v$CURRENT_VER"
else
  log_info "Installing new promtail v$CLEAN_VERSION..."
fi

log_step "Downloading $DOWNLOAD_URL ..."
cd /tmp
curl -fSL "$DOWNLOAD_URL" -o "$ZIP_NAME"
unzip -o "$ZIP_NAME"
sudo mv "$BINARY_NAME" "$BIN_PATH"
sudo chmod +x "$BIN_PATH"
rm "$ZIP_NAME"

log_ok "Promtail binary installed to $BIN_PATH"

# ─── 5. Configuration Setup ───
print_section "Configuration"

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
          expression: '^(?P<host>[^ ]+) (?P<ip>[^ ]+) - (?P<user>[^ ]+) \[(?P<timestamp>[^\]]+)\] "(?P<method>\S+) (?P<path>\S+) (?P<http_version>[^"]+)" (?P<status_code>\d+) (?P<size>\d+)'
      - labels:
          host:
          status_code:
      - timestamp:
          source: timestamp
          format: '02/Jan/2006:15:04:05 -0700'
EOF

log_ok "Config generated at $CONFIG_FILE"

# ─── 6. Service Setup ───
print_section "Systemd Service"

SERVICE_FILE="/etc/systemd/system/promtail.service"

log_info "Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Promtail service
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
sudo systemctl enable promtail
sudo systemctl restart promtail

log_ok "Promtail service is running"

# final check
sudo systemctl is-active promtail || log_error "Gagal menjalankan promtail. Cek logs: journalctl -u promtail"

# ─── Done ───
echo ""
print_section "SUMMARY"
log_ok "🎉 Promtail berhasil di-$(if command -v promtail &>/dev/null; then echo "update"; else echo "install"; fi)!"
log_info "Loki URL  : $LOKI_URL"
log_info "Hostname  : $SERVER_NAME"
log_info "Config    : $CONFIG_FILE"
log_info "Path Logs : /var/log/nginx/access-vhost.log"
echo ""
