#!/bin/bash
# ============================================================
# Module: Provisioning - Setup Server Baru
# Fungsi: Create user devops, SSH keys, sudoers, timezone
# ============================================================

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
source "$SCRIPT_DIR/../../lib/ssh.sh"

print_banner "Server Provisioning"

# ─── Config ───
print_section "Configuration"

SERVER_LIST="${1:-servers.txt}"
if [[ ! -f "$SERVER_LIST" ]]; then log_error "File server list tidak ditemukan: $SERVER_LIST"; exit 1; fi

# Show server list
SERVER_COUNT=$(grep -v '^#' "$SERVER_LIST" | grep -v '^$' | wc -l | xargs)
log_info "Server list: $SERVER_LIST ($SERVER_COUNT server)"
echo ""

read -rp "  SSH User awal [ubuntu]: " SSH_USER
SSH_USER=${SSH_USER:-ubuntu}

read -rp "  SSH Key path [$HOME/.ssh/id_rsa_baremetal]: " SSH_KEY
SSH_KEY=${SSH_KEY:-$HOME/.ssh/id_rsa_baremetal}

read -rp "  Timezone [Asia/Jakarta]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Jakarta}

echo ""
read -s -rp "  Password $SSH_USER (fallback jika SSH key gagal): " UBUNTU_PASS
echo ""

read -s -rp "  Password untuk user devops (jika user belum ada): " DEVOPS_PASS
echo ""

echo "  Paste PUBLIC KEY untuk user devops (akhiri dengan ENTER):"
read -r DEVOPS_PUBKEY

if [[ -z "$DEVOPS_PUBKEY" ]]; then log_error "Public key tidak boleh kosong!"; exit 1; fi

echo ""
if ! confirm "Mulai provisioning $SERVER_COUNT server?"; then log_info "Dibatalkan"; exit 0; fi

# ─── Process Servers ───
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_HOSTS=()

# Gunakan 'for' agar loop stabil
for HOST in $(grep -v '^#' "$SERVER_LIST" | grep -v '^$'); do
  HOST=$(echo "$HOST" | xargs)
  print_section "Processing: $HOST"

  # Kita suntikkan variabel ke dalam remote command secara langsung (tanpa Base64)
  # Gunakan single quotes di remote side agar lancar
  REMOTE_CMD="
    set -e
    
    # ─── Setup SSH Rules ───
    sudo mkdir -p /etc/ssh/sshd_config.d
    sudo tee /etc/ssh/sshd_config.d/01-rule.conf >/dev/null << 'EOF_SSHD'
PasswordAuthentication yes
PubkeyAuthentication yes

Match User $SSH_USER
    PasswordAuthentication no
    PubkeyAuthentication yes

Match User devops
    PasswordAuthentication yes
    PubkeyAuthentication yes
EOF_SSHD

    sudo sshd -t
    sudo systemctl restart ssh || sudo systemctl restart sshd

    # ─── Create user devops ───
    if id devops >/dev/null 2>&1; then
        echo \"User devops sudah ada\"
    else
        echo \"Membuat user devops...\"
        sudo useradd -m -s /bin/bash devops
    fi
     # Force update password
    echo \"devops:$DEVOPS_PASS\" | sudo chpasswd

    # ─── Sudoers ───
    sudo usermod -aG sudo devops 2>/dev/null || sudo usermod -aG wheel devops 2>/dev/null || true
    echo \"devops ALL=(ALL) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/devops >/dev/null
    sudo chmod 440 /etc/sudoers.d/devops

    # ─── SSH key setup ───
    sudo install -m 700 -o devops -g devops -d /home/devops/.ssh
    if ! sudo grep -qxF \"$DEVOPS_PUBKEY\" /home/devops/.ssh/authorized_keys 2>/dev/null; then
        echo \"$DEVOPS_PUBKEY\" | sudo tee -a /home/devops/.ssh/authorized_keys >/dev/null
    fi
    sudo chown -R devops:devops /home/devops/.ssh
    sudo chmod 600 /home/devops/.ssh/authorized_keys

    # ─── Timezone ───
    if command -v timedatectl >/dev/null 2>&1; then
        sudo timedatectl set-timezone $TIMEZONE
    else
        sudo ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    fi

    echo \"✅ Server provisioning selesai\"
  "

  # Execute (penting: tambahkan < /dev/null agar SSH tidak mencuri stdin loop)
  if ssh_smart_exec "$SSH_USER" "$HOST" "$SSH_KEY" "$UBUNTU_PASS" "$REMOTE_CMD" < /dev/null; then
    log_ok "🎉 SUCCESS: $HOST"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    log_error "❌ FAILED: $HOST"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_HOSTS+=("$HOST")
  fi
  echo ""
done

# Summary
print_section "Summary"
log_ok "Success: $SUCCESS_COUNT server"
if [[ $FAIL_COUNT -gt 0 ]]; then
  log_error "Failed: $FAIL_COUNT server"
  for h in "${FAILED_HOSTS[@]}"; do echo "    ❌ $h"; done
fi
