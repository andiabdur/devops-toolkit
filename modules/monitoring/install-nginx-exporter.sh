#!/bin/bash
# ============================================================
# Module: Monitoring - Install Nginx Prometheus Exporter
# Fungsi: Install Exporter dan Setup Stub Status Nginx
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Nginx Exporter Installer"

# ─── 0. Prerequisites ───
if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
  log_info "Installing prerequisites (jq, curl)..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -yqq && sudo apt-get install -y jq curl tar
  elif command -v yum &>/dev/null; then
    sudo yum install -y epel-release && sudo yum install -y jq curl tar
  fi
fi

# ─── 1. Setup Nginx Stub Status ───
print_section "Nginx Stub Status Configuration"

GATEWAY_DIR="/home/devops/gateway"
STATUS_CONF="$GATEWAY_DIR/stub_status.conf"

log_info "Creating Nginx status config at $STATUS_CONF ..."
sudo mkdir -p "$GATEWAY_DIR"
sudo tee "$STATUS_CONF" > /dev/null <<EOF
server {
    listen 8080;
    server_name localhost;

    location /stub_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

log_ok "Draft config created at $STATUS_CONF"
log_warn "PASTIKAN Nginx kamu me-load config dari $GATEWAY_DIR (cek nginx.conf include)."
if command -v nginx &>/dev/null; then
  log_info "Reloading Nginx..."
  sudo nginx -s reload || log_warn "Gagal reload Nginx. Pastikan config sudah di-include dengan benar."
fi

# ─── 2. Fetch Latest Exporter ───
print_section "Discovering Versions"

OS_ARCH=$(uname -m)
case "$OS_ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *)       ARCH="amd64" ; log_warn "Arsitektur tidak didukung otomatis ($OS_ARCH), menggunakan default amd64" ;;
esac

LATEST_VERSION=$(curl -s "https://api.github.com/repos/nginxinc/nginx-prometheus-exporter/releases/latest" | jq -r .tag_name | sed 's/^v//')
log_ok "Versi terbaru ditemukan: v$LATEST_VERSION"

# ─── 3. Install Binary ───
print_section "Installing Nginx Exporter Binary"

TAR_NAME="nginx-prometheus-exporter_${LATEST_VERSION}_linux_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v${LATEST_VERSION}/${TAR_NAME}"
BIN_PATH="/usr/local/bin/nginx-prometheus-exporter"

log_step "Downloading $DOWNLOAD_URL ..."
cd /tmp
if ! curl -fSL "$DOWNLOAD_URL" -o "$TAR_NAME"; then
  log_error "Gagal mendownload Nginx Exporter v$LATEST_VERSION."
  exit 1
fi

tar xvf "$TAR_NAME"
sudo mv nginx-prometheus-exporter "$BIN_PATH"
sudo chmod +x "$BIN_PATH"
rm "$TAR_NAME"
log_ok "Nginx Exporter binary v$LATEST_VERSION terpasang."

# ─── 4. Service Setup ───
print_section "Systemd Service"

SERVICE_FILE="/etc/systemd/system/nginx-exporter.service"
log_info "Creating systemd service..."

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Nginx Prometheus Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BIN_PATH -nginx.scrape-uri=http://127.0.0.1:8080/stub_status
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nginx-exporter
sudo systemctl restart nginx-exporter

log_ok "Nginx Exporter service started."

# ─── 5. Verification ───
print_section "Verification"
sleep 2
if curl -s localhost:9113/metrics | grep -q "nginx_"; then
  log_ok "🎉 Nginx Exporter is ACTIVE at http://localhost:9113/metrics"
else
  log_warn "Nginx Exporter tidak merespon metrics. Pastikan stub_status di port 8080 sudah jalan."
fi

echo ""
print_section "SUMMARY"
log_info "Nginx Status : http://127.0.0.1:8080/stub_status"
log_info "Exporter URL : http://localhost:9113/metrics"
log_info "Config Path  : $STATUS_CONF"
echo ""
