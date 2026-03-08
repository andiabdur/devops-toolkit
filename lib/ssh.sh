#!/bin/bash
# ============================================================
# DevOps Toolkit - SSH Shared Library
# Fungsi-fungsi reusable untuk remote SSH execution
# ============================================================

[[ -n "$_LIB_SSH_LOADED" ]] && return 0
_LIB_SSH_LOADED=1

# Load common library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# ─── Test SSH key login ───
# Usage: test_ssh_key "user" "host" "key_path"
# Returns: 0 if success, 1 if failed
test_ssh_key() {
  local user="$1"
  local host="$2"
  local key="$3"

  ssh -o BatchMode=yes -o ConnectTimeout=5 -i "$key" "${user}@${host}" "echo ok" >/dev/null 2>&1
  return $?
}

# ─── Execute remote command via SSH (key-based) ───
# Usage: ssh_exec_key "user" "host" "key_path" "command"
ssh_exec_key() {
  local user="$1"
  local host="$2"
  local key="$3"
  local cmd="$4"

  ssh -tt -i "$key" -o StrictHostKeyChecking=no "${user}@${host}" "$cmd"
}

# ─── Execute remote command via SSH (password-based) ───
# Usage: ssh_exec_pass "user" "host" "password" "command"
ssh_exec_pass() {
  local user="$1"
  local host="$2"
  local password="$3"
  local cmd="$4"

  require_command "sshpass" "sudo apt install sshpass -y"

  SSHPASS="$password" sshpass -e ssh -tt \
    -o StrictHostKeyChecking=no \
    -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no \
    "${user}@${host}" "$cmd"
}

# ─── Smart SSH exec: try key first, fallback to password ───
# Usage: ssh_smart_exec "user" "host" "key_path" "password" "command"
ssh_smart_exec() {
  local user="$1"
  local host="$2"
  local key="$3"
  local password="$4"
  local cmd="$5"

  if test_ssh_key "$user" "$host" "$key"; then
    log_ok "Login via SSH key"
    ssh_exec_key "$user" "$host" "$key" "$cmd"
  else
    log_warn "SSH key failed, using password"
    ssh_exec_pass "$user" "$host" "$password" "$cmd"
  fi
}
