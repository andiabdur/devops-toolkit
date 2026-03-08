#!/bin/bash
# ============================================================
# Module: Kubernetes - Install KubeSphere Dashboard
# Fungsi: Download images, import to containerd, install via Helm
# ============================================================
set -e

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "KubeSphere Dashboard Install"

# ─── Config ───
print_section "Configuration"

DEFAULT_URL="https://github.com/config-devops/Kubesphare-v4.1.3/releases/download/4.1.3"

read -rp "  KubeSphere version [v4.1.3]: " VERSION
VERSION=${VERSION:-v4.1.3}

read -rp "  Base URL for images [${DEFAULT_URL}]: " BASE_URL
BASE_URL=${BASE_URL:-$DEFAULT_URL}

read -rp "  Helm chart filename [ks-core-1.1.4.tgz]: " HELM_TGZ
HELM_TGZ=${HELM_TGZ:-ks-core-1.1.4.tgz}

WORKDIR="/tmp/kubesphere-installer"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ─── Precheck ───
require_command "helm" "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
require_command "wget"

# ─── Download Images ───
print_section "Download KubeSphere Images"

IMAGES=(
  "ks-console-${VERSION}.tar:ks-console.tar"
  "ks-apiserver-${VERSION}.tar:ks-apiserver.tar"
  "ks-controller-manager-${VERSION}.tar:ks-controller-manager.tar"
  "extensions-museum-${VERSION}.tar:extensions-museum.tar"
)

for img in "${IMAGES[@]}"; do
  remote="${img%%:*}"
  local_name="${img##*:}"

  if [[ -f "$local_name" ]]; then
    log_ok "$local_name already downloaded, skip"
  else
    log_info "Downloading $remote..."
    wget -q "${BASE_URL}/${remote}" -O "$local_name" || {
      log_error "Failed to download $remote"
      exit 1
    }
    log_ok "Downloaded $local_name"
  fi
done

# ─── Import images into containerd ───
print_section "Import Images to Containerd"

for img in "${IMAGES[@]}"; do
  local_name="${img##*:}"
  log_info "Importing $local_name..."
  sudo ctr -n k8s.io images import "$local_name"
  log_ok "Imported $local_name"
done

# ─── Download Helm Chart ───
print_section "Install via Helm"

if [[ ! -f "$HELM_TGZ" ]]; then
  log_info "Downloading Helm chart..."
  wget -q "${BASE_URL}/${HELM_TGZ}" || {
    log_error "Failed to download Helm chart"
    exit 1
  }
fi

log_info "Installing KubeSphere via Helm..."
helm upgrade --install ks-core "$HELM_TGZ" \
  -n kubesphere-system --create-namespace

echo ""
log_ok "🎉 KubeSphere ${VERSION} installation completed!"
echo ""
echo "  ${CYAN}Default credentials:${RESET}"
echo "  ${WHITE}Username: admin${RESET}"
echo "  ${WHITE}Password: P@88w0rd${RESET}"
echo ""
log_warn "Segera ganti password default setelah login!"
