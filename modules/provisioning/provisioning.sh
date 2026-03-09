#!/bin/bash
# ============================================================
# Module: Provisioning - Setup Server Baru
# Fungsi: Create user devops, SSH keys, sudoers, timezone
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
source "$SCRIPT_DIR/../../lib/ssh.sh"

print_banner "Server Provisioning"

# ─── Config ───
print_section "Configuration"

SERVER_LIST="${1:-servers.txt}"

if [[ ! -f "$SERVER_LIST" ]]; then
  log_error "File server list tidak ditemukan: $SERVER_LIST"
  log_info "Buat file terlebih dahulu, contoh:"
  echo "    echo '192.168.1.10' > servers.txt"
  echo "    echo '192.168.1.11' >> servers.txt"
  echo ""
  log_info "Atau jalankan dengan: bash provisioning.sh /path/to/servers.txt"
  exit 1
fi

# Show server list
SERVER_COUNT=$(wc -l < "$SERVER_LIST" | xargs)
log_info "Server list: $SERVER_LIST ($SERVER_COUNT server)"
echo ""
cat "$SERVER_LIST" | while read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  echo "    → $line"
done
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

if [[ -z "$DEVOPS_PUBKEY" ]]; then
  log_error "Public key tidak boleh kosong!"
  exit 1
fi

echo ""
if ! confirm "Mulai provisioning $SERVER_COUNT server?"; then
  log_info "Dibatalkan"
  exit 0
fi

# ─── Process Servers ───
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_HOSTS=()

# Pre-encode variables locally to prevent SSH/Shell parsing injection
B64_UBUNTU_PASS=$(printf '%s' "$UBUNTU_PASS" | base64 | tr -d '\n')
B64_DEVOPS_PASS=$(printf '%s' "$DEVOPS_PASS" | base64 | tr -d '\n')
B64_PUBKEY=$(printf '%s' "$DEVOPS_PUBKEY" | base64 | tr -d '\n')

while IFS= read -r HOST || [[ -n "$HOST" ]]; do
  # Skip empty lines and comments
  [[ -z "$HOST" || "$HOST" =~ ^# ]] && continue
  HOST=$(echo "$HOST" | xargs)

  print_section "Processing: $HOST"

  # Build remote command via Base64 to safely bridge over SSH shell parsing
  REMOTE_SCRIPT_PLAIN=$(
cat <<EOF_INJECT
B64_UBUNTU_PASS="${B64_UBUNTU_PASS}"
B64_DEVOPS_PASS="${B64_DEVOPS_PASS}"
B64_DEVOPS_PUBKEY="${B64_PUBKEY}"
VAR_SSH_USER="${SSH_USER}"
VAR_TIMEZONE="${TIMEZONE}"
EOF_INJECT
cat <<'EOF_SCRIPT'
UBUNTU_PASS_DEC=$(echo "$B64_UBUNTU_PASS" | { base64 -d 2>/dev/null || base64 --decode; })
DEVOPS_PASS_DEC=$(echo "$B64_DEVOPS_PASS" | { base64 -d 2>/dev/null || base64 --decode; })
PUBKEY_DEC=$(echo "$B64_DEVOPS_PUBKEY" | { base64 -d 2>/dev/null || base64 --decode; })

SCRIPT_PATH="/tmp/prov_$(date +%s)_$RANDOM.sh"
cat <<'EOF_ROOT' > "$SCRIPT_PATH"
set -e

ARG_DEVOPS_PASS=$1
ARG_SSH_USER=$2
ARG_TIMEZONE=$3
ARG_PUBKEY=$4

# ─── SSH Config ───
mkdir -p /etc/ssh/sshd_config.d

tee /etc/ssh/sshd_config.d/01-rule.conf >/dev/null <<SSHEOF
PasswordAuthentication yes
PubkeyAuthentication yes

Match User ${ARG_SSH_USER}
    PasswordAuthentication no
    PubkeyAuthentication yes

Match User devops
    PasswordAuthentication yes
    PubkeyAuthentication yes
SSHEOF

sshd -t
systemctl restart ssh || systemctl restart sshd

# ─── Create user devops ───
if id devops >/dev/null 2>&1; then
    echo "User devops sudah ada"
else
    echo "Membuat user devops..."
    useradd -m -s /bin/bash devops
    echo "devops:${ARG_DEVOPS_PASS}" | chpasswd
fi

# ─── Sudoers ───
usermod -aG sudo devops 2>/dev/null || usermod -aG wheel devops 2>/dev/null || true
echo "devops ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/devops >/dev/null
chmod 440 /etc/sudoers.d/devops
visudo -cf /etc/sudoers.d/devops

# ─── SSH key setup ───
install -m 700 -o devops -g devops -d /home/devops/.ssh

if ! grep -qxF "${ARG_PUBKEY}" /home/devops/.ssh/authorized_keys 2>/dev/null; then
    echo "${ARG_PUBKEY}" | tee -a /home/devops/.ssh/authorized_keys >/dev/null
fi

chown -R devops:devops /home/devops/.ssh
chmod 600 /home/devops/.ssh/authorized_keys

# ─── Timezone ───
if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone ${ARG_TIMEZONE}
else
    ln -sf /usr/share/zoneinfo/${ARG_TIMEZONE} /etc/localtime
fi

echo "✅ Server provisioning selesai"
EOF_ROOT

chmod +x "$SCRIPT_PATH"
printf '%s\n' "$UBUNTU_PASS_DEC" | sudo -S -p "" bash "$SCRIPT_PATH" "$DEVOPS_PASS_DEC" "$VAR_SSH_USER" "$VAR_TIMEZONE" "$PUBKEY_DEC"
EXIT_CODE=$?
rm -f "$SCRIPT_PATH"
exit $EXIT_CODE
EOF_SCRIPT
  )

  REMOTE_CMD_B64=$(printf "%s" "$REMOTE_SCRIPT_PLAIN" | base64 | tr -d '\n')
  REMOTE_CMD="echo '${REMOTE_CMD_B64}' | { base64 -d 2>/dev/null || base64 --decode; } | bash"

  # Execute via smart SSH (try key, fallback password)
  if ssh_smart_exec "$SSH_USER" "$HOST" "$SSH_KEY" "$UBUNTU_PASS" "$REMOTE_CMD" < /dev/null; then
    log_ok "🎉 SUCCESS: $HOST"
    ((SUCCESS_COUNT++))
  else
    log_error "❌ FAILED: $HOST"
    ((FAIL_COUNT++))
    FAILED_HOSTS+=("$HOST")
  fi

  echo ""
done < "$SERVER_LIST"

# ─── Summary ───
print_section "Summary"

log_ok "Success: $SUCCESS_COUNT server"
if [[ $FAIL_COUNT -gt 0 ]]; then
  log_error "Failed: $FAIL_COUNT server"
  for h in "${FAILED_HOSTS[@]}"; do
    echo "    ❌ $h"
  done
fi
