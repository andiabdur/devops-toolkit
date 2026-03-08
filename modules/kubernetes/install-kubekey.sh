#!/bin/bash
# ============================================================
# Module: Kubernetes - Install KubeKey
# Fungsi: Download KubeKey, generate config, create cluster
# ============================================================
set -e

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Kubernetes Cluster Setup (KubeKey)"

# ─── 1. Download KubeKey ───
print_section "Download KubeKey"

if [ -f "./kk" ]; then
  log_ok "KubeKey sudah ada, skip download"
else
  log_info "Downloading KubeKey..."
  curl -sfL https://get-kk.kubesphere.io | sh -
fi

chmod +x kk

# ─── 2. Input Config ───
print_section "Input Config Data"

read -rp "  ${WHITE}Versi Kubernetes (contoh: v1.33.1): ${RESET}" k8s_version
read -rp "  ${WHITE}Nama file config (contoh: config-cluster.yaml): ${RESET}" config_file
read -rp "  ${WHITE}Berapa jumlah node? ${RESET}" node_count

# Validate node count
if ! [[ "$node_count" =~ ^[0-9]+$ ]] || [[ "$node_count" -lt 1 ]]; then
  log_error "Jumlah node harus minimal 1"
  exit 1
fi

# ─── Auth Mode ───
echo ""
echo "  ${WHITE}Pilih metode autentikasi SSH ke node:${RESET}"
echo "    ${GREEN}1)${RESET} Password"
echo "    ${GREEN}2)${RESET} SSH Key (Private Key)"
echo ""
read -rp "  ${WHITE}Pilih [1/2]: ${RESET}" auth_mode

if [[ "$auth_mode" != "1" && "$auth_mode" != "2" ]]; then
  log_error "Pilihan tidak valid, harus 1 atau 2"
  exit 1
fi

common_user=""
common_pass=""
common_key_path=""
same_credential=""

if [[ "$auth_mode" == "1" ]]; then
  log_info "Mode: ${GREEN}Password${RESET}"
elif [[ "$auth_mode" == "2" ]]; then
  log_info "Mode: ${GREEN}SSH Key${RESET}"
fi

if [[ "$node_count" -gt 1 ]]; then
  read -rp "  ${WHITE}Semua node pakai credential sama? (Y/N): ${RESET}" same_credential

  if [[ "$same_credential" =~ ^[Yy]$ ]]; then
    read -rp "    User: " common_user

    if [[ "$auth_mode" == "1" ]]; then
      read -s -rp "    Password: " common_pass
      echo ""
    else
      read -rp "    Private key path (contoh: ~/.ssh/id_rsa): " common_key_path
      # Expand ~ ke full path
      common_key_path="${common_key_path/#\~/$HOME}"
      if [[ ! -f "$common_key_path" ]]; then
        log_warn "File '$common_key_path' tidak ditemukan di mesin ini (mungkin ada di target server)"
      fi
    fi
  fi
fi

# ─── 3. Input Node Details ───
print_section "Input Node Details"

hosts_block=""
etcd_group=""
control_plane_group=""
worker_group=""

for (( i=1; i<=node_count; i++ )); do
  echo ""
  log_step "Node ke-$i dari $node_count"
  read -rp "    Name: " node_name

  # Validasi IP
  while true; do
    read -rp "    Address (IP): " node_ip
    if validate_ip "$node_ip"; then
      break
    else
      log_error "IP tidak valid! Contoh: 192.168.1.10"
    fi
  done

  if [[ "$same_credential" =~ ^[Yy]$ ]]; then
    node_user="$common_user"
    node_pass="$common_pass"
    node_key="$common_key_path"
  else
    read -rp "    User: " node_user

    if [[ "$auth_mode" == "1" ]]; then
      read -s -rp "    Password: " node_pass
      node_key=""
      echo ""
    else
      node_pass=""
      read -rp "    Private key path (contoh: ~/.ssh/id_rsa): " node_key
      node_key="${node_key/#\~/$HOME}"
    fi
  fi

  # Generate hosts block berdasarkan auth mode
  if [[ "$auth_mode" == "1" ]]; then
    hosts_block+="    - {name: $node_name, address: $node_ip, internalAddress: $node_ip, user: $node_user, password: \"$node_pass\"}\n"
  else
    hosts_block+="    - {name: $node_name, address: $node_ip, internalAddress: $node_ip, user: $node_user, privateKeyPath: \"$node_key\"}\n"
  fi

  # Node pertama → etcd + control-plane + worker
  # Node lainnya → worker
  if [[ $i -eq 1 ]]; then
    etcd_group+="      - $node_name\n"
    control_plane_group+="      - $node_name\n"
    worker_group+="      - $node_name\n"
  else
    worker_group+="      - $node_name\n"
  fi
done

# ─── 4. Optional: Network & Endpoint Config ───
print_section "Network Config (tekan Enter untuk default)"

read -rp "  Control Plane Domain [lb.kubesphere.local]: " cp_domain
cp_domain=${cp_domain:-lb.kubesphere.local}

read -rp "  Pod CIDR [10.233.64.0/18]: " pod_cidr
pod_cidr=${pod_cidr:-10.233.64.0/18}

read -rp "  Service CIDR [10.233.0.0/18]: " svc_cidr
svc_cidr=${svc_cidr:-10.233.0.0/18}

read -rp "  CNI Plugin [calico]: " cni_plugin
cni_plugin=${cni_plugin:-calico}

# ─── 5. Generate Config ───
print_section "Generate Config File"

cat > "$config_file" <<EOF
apiVersion: kubekey.kubesphere.io/v1alpha2
kind: Cluster
metadata:
  name: sample
spec:
  hosts:
$(echo -e "$hosts_block")
  roleGroups:
    etcd:
$(echo -e "$etcd_group")
    control-plane:
$(echo -e "$control_plane_group")
    worker:
$(echo -e "$worker_group")
  controlPlaneEndpoint:
    domain: ${cp_domain}
    address: ""
    port: 6443

  kubernetes:
    version: ${k8s_version}
    clusterName: cluster.local
    autoRenewCerts: true
    containerManager: containerd

  etcd:
    type: kubekey

  network:
    plugin: ${cni_plugin}
    kubePodsCIDR: ${pod_cidr}
    kubeServiceCIDR: ${svc_cidr}
    multusCNI:
      enabled: false

  registry:
    privateRegistry: ""
    namespaceOverride: ""
    registryMirrors: []
    insecureRegistries: []

  addons: []
EOF

log_ok "Config berhasil dibuat: $config_file"
log_info "Kubernetes version: $k8s_version"
log_info "Node count: $node_count"
log_info "Auth mode: $(if [[ "$auth_mode" == "1" ]]; then echo "Password"; else echo "SSH Key"; fi)"
log_info "CNI: $cni_plugin"

# ─── 6. Create Cluster ───
if confirm "Jalankan create cluster sekarang?"; then
  countdown 5 "Mulai dalam"
  log_step "Menjalankan: ./kk create cluster -f $config_file"
  ./kk create cluster -f "$config_file"

  echo ""
  log_ok "🎉 Cluster berhasil dibuat!"
else
  echo ""
  log_info "Cluster tidak dijalankan. Jalankan manual dengan:"
  echo "  ./kk create cluster -f $config_file"
fi
