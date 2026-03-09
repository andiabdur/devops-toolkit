#!/bin/bash
# ============================================================
# Module: Provisioning - Install Kubernetes Dependencies
# Fungsi: Install socat, conntrack, ipvsadm, etc. secara massal
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
source "$SCRIPT_DIR/../../lib/ssh.sh"

print_banner "Install Kubernetes Dependencies"

# ─── Config ───
print_section "Configuration"

SERVER_LIST="${1:-servers.txt}"

if [[ ! -f "$SERVER_LIST" ]]; then
  log_error "File server list tidak ditemukan: $SERVER_LIST"
  exit 1
fi

# Show server list
SERVER_COUNT=$(grep -v '^#' "$SERVER_LIST" | grep -v '^$' | wc -l | xargs)
log_info "Server list: $SERVER_LIST ($SERVER_COUNT server)"
echo ""

read -rp "  SSH User awal [ubuntu]: " SSH_USER
SSH_USER=${SSH_USER:-ubuntu}

read -rp "  SSH Key path [$HOME/.ssh/id_rsa_baremetal]: " SSH_KEY
SSH_KEY=${SSH_KEY:-$HOME/.ssh/id_rsa_baremetal}

echo ""
read -s -rp "  Password $SSH_USER (untuk sudo & fallback SSH): " UBUNTU_PASS
echo ""

if ! confirm "Mulai instalasi dependencies di $SERVER_COUNT server?"; then
  log_info "Dibatalkan"
  exit 0
fi

# ─── Process Servers ───
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_HOSTS=()

# Pre-encode variables locally
B64_UBUNTU_PASS=$(printf '%s' "$UBUNTU_PASS" | base64 | tr -d '\n')

# Gunakan 'for' agar loop tidak terganggu oleh stdin
for HOST in $(grep -v '^#' "$SERVER_LIST" | grep -v '^$'); do
  HOST=$(echo "$HOST" | xargs)
  print_section "Processing: $HOST"

  # Build remote command via Base64
  REMOTE_SCRIPT_PLAIN=$(
cat <<EOF_INJECT
B64_UBUNTU_PASS="${B64_UBUNTU_PASS}"
EOF_INJECT
cat <<'EOF_SCRIPT'
UBUNTU_PASS_DEC=$(echo "$B64_UBUNTU_PASS" | { base64 -d 2>/dev/null || base64 --decode; })

SCRIPT_PATH="/tmp/k8s_deps_$(date +%s)_$RANDOM.sh"
cat <<'EOF_ROOT' > "$SCRIPT_PATH"
set -e
echo "[INFO] Detecting OS and installing dependencies..."

if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -yqq
    apt-get install -yqq socat conntrack ipset ipvsadm ebtables jq curl
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q socat conntrack ipset ipvsadm ebtables jq curl
else
    echo "❌ OS tidak didukung (hanya apt/yum)"
    exit 1
fi
echo "✅ Dependencies terinstall."
EOF_ROOT

chmod +x "$SCRIPT_PATH"
printf '%s\n' "$UBUNTU_PASS_DEC" | sudo -S -p "" bash "$SCRIPT_PATH"
EXIT_CODE=$?
rm -f "$SCRIPT_PATH"
exit $EXIT_CODE
EOF_SCRIPT
  )

  REMOTE_CMD_B64=$(printf "%s" "$REMOTE_SCRIPT_PLAIN" | base64 | tr -d '\n')
  REMOTE_CMD="echo '${REMOTE_CMD_B64}' | { base64 -d 2>/dev/null || base64 --decode; } | bash"

  # Execute via smart SSH (isolasikan stdin dengan < /dev/null)
  if ssh_smart_exec "$SSH_USER" "$HOST" "$SSH_KEY" "$UBUNTU_PASS" "$REMOTE_CMD" < /dev/null; then
    log_ok "🎉 SUCCESS: $HOST"
    ((SUCCESS_COUNT++))
  else
    log_error "❌ FAILED: $HOST"
    ((FAIL_COUNT++))
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
