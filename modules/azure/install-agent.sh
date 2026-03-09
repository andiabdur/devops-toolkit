#!/bin/bash
# ============================================================
# Module: Azure DevOps Agent - Self-Hosted Agent Installer
# Fungsi: Install Azure DevOps Agent dengan auto-versioning
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Azure DevOps Agent Installer"

# ─── 1. Discover Latest Version ───
print_section "Checking Latest Agent Version"

log_info "Fetching latest agent version from GitHub..."
OS_ARCH=$(uname -m)
case "$OS_ARCH" in
  x86_64)  ARCH="x64" ;;
  aarch64) ARCH="arm64" ;;
  *)       ARCH="x64" ; log_warn "Arsitektur tidak didukung otomatis ($OS_ARCH), menggunakan default x64" ;;
esac

LATEST_VERSION=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

if [[ -z "$LATEST_VERSION" ]]; then
  LATEST_VERSION="4.266.2" # Fallback if API fails
  log_warn "Gagal mendapatkan versi terbaru dari GitHub API, menggunakan fallback: $LATEST_VERSION"
else
  log_ok "Versi terbaru ditemukan: $LATEST_VERSION"
fi

# ─── 2. Input Configuration ───
print_section "Agent Configuration"

read -rp "  Azure DevOps Org URL [https://dev.azure.com/bersama-teknologi-unggul]: " AZP_URL
AZP_URL=${AZP_URL:-https://dev.azure.com/bersama-teknologi-unggul}

read -s -rp "  Azure DevOps PAT (AZP_TOKEN): " AZP_TOKEN
echo ""

if [[ -z "$AZP_TOKEN" ]]; then
  log_error "PAT Token tidak boleh kosong!"
  exit 1
fi

read -rp "  Agent Pool [btu-server-dev]: " AZP_POOL
AZP_POOL=${AZP_POOL:-btu-server-dev}

read -rp "  Agent Name [$(hostname)]: " AZP_AGENT_NAME
AZP_AGENT_NAME=${AZP_AGENT_NAME:-$(hostname)}

read -rp "  Agent Version [$LATEST_VERSION]: " AGENT_VERSION
AGENT_VERSION=${AGENT_VERSION:-$LATEST_VERSION}

read -rp "  Install Directory [$HOME/myagent]: " AGENT_DIR
AGENT_DIR=${AGENT_DIR:-$HOME/myagent}

# ─── 3. Dependencies ───
print_section "Installing Dependencies"

log_info "Checking & installing dependencies (curl, tar, jq)..."
if command -v apt-get &>/dev/null; then
  sudo apt-get update -yqq && sudo apt-get install -y curl tar jq libicu-dev
  log_ok "Dependensi (curl, tar, jq, libicu) terinstall via apt"
elif command -v yum &>/dev/null; then
  sudo yum install -y curl tar jq libicu
  log_ok "Dependensi (curl, tar, jq, libicu) terinstall via yum"
else
  log_warn "Paket manager tidak didukung. Pastikan curl, tar, jq sudah terinstall."
fi

# ─── 4. Download & Extract ───
print_section "Downloading Agent"

AGENT_PACKAGE="vsts-agent-linux-${ARCH}-${AGENT_VERSION}.tar.gz"
DOWNLOAD_URL="https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/${AGENT_PACKAGE}"

mkdir -p "$AGENT_DIR"
cd "$AGENT_DIR"

if [[ ! -f "$AGENT_PACKAGE" ]]; then
  log_info "Downloading from: $DOWNLOAD_URL"
  if curl -fSL "$DOWNLOAD_URL" -o "$AGENT_PACKAGE"; then
    log_ok "Download berhasil: $AGENT_PACKAGE"
  else
    # Try alternate location
    DOWNLOAD_URL_ALT="https://download.agent.dev.azure.com/agent/$AGENT_VERSION/$AGENT_PACKAGE"
    log_warn "Gagal mengunduh dari primary, mencoba dari failover: $DOWNLOAD_URL_ALT"
    curl -fSL "$DOWNLOAD_URL_ALT" -o "$AGENT_PACKAGE" || { log_error "Gagal mengunduh agent" ; exit 1 ; }
  fi
fi

log_info "Extracting..."
tar -xzf "$AGENT_PACKAGE"
chmod +x ./config.sh ./bin/Agent.Listener

# ─── 5. Configuration ───
print_section "Configuring Agent"

if [[ ! -f ".agent" ]]; then
  log_info "Menjalankan ./config.sh (UNATTENDED)..."
  ./config.sh --unattended \
    --url "$AZP_URL" \
    --auth pat \
    --token "$AZP_TOKEN" \
    --pool "$AZP_POOL" \
    --agent "$AZP_AGENT_NAME" \
    --acceptTeeEula \
    --work _work \
    --replace
  log_ok "Agent dikonfigurasi"
else
  log_info "Agent sudah dikonfigurasi sebelumnya (.agent file ditemukan)"
fi

# ─── 6. Service Management ───
print_section "Service Setup"

log_info "Registering as a systemd service..."
# SVC_SCRIPT handles starting/stopping as a service
SVC_SCRIPT="./svc.sh"
[[ -f "./bin/svc.sh" ]] && SVC_SCRIPT="./bin/svc.sh"
chmod +x "$SVC_SCRIPT"

if [[ "$MODE" != "reinstall" ]]; then
  sudo "$SVC_SCRIPT" install || log_warn "Sudah terinstall atau gagal install service"
fi

sudo "$SVC_SCRIPT" start
log_ok "Service started!"

# ─── 7. Optional Workload: MSSQL (As per original script) ───
if command -v mssql-conf &>/dev/null; then
  print_section "Workload: MSSQL Config"
  log_info "Detecting MSSQL, enabling SQL Agent..."
  sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
  sudo systemctl restart mssql-server
  log_ok "SQL Agent enabled and MSSQL restarted"
fi

# ─── Done ───
echo ""
print_section "INSTALLATION COMPLETE"
log_ok "🎉 Azure DevOps Agent berhasil terinstal di $AGENT_DIR"
log_info "Cek status service:"
echo "    sudo $SVC_SCRIPT status"
echo ""
