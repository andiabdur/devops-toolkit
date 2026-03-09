#!/bin/bash
# ============================================================
# DevOps Toolkit - SSH Shared Library
# ============================================================

[[ -n "$_LIB_SSH_LOADED" ]] && return 0
_LIB_SSH_LOADED=1

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Test SSH key login
test_ssh_key() {
  local user="$1"
  local host="$2"
  local key="$3"
  ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$key" "${user}@${host}" "echo ok" >/dev/null 2>&1
  return $?
}

# Execute via SSH (key-based)
ssh_exec_key() {
  local user="$1"
  local host="$2"
  local key="$3"
  local cmd="$4"
  ssh -i "$key" -o StrictHostKeyChecking=no -o ConnectTimeout=15 "${user}@${host}" "$cmd"
}

# Execute via SSH (password-based)
ssh_exec_pass() {
  local user="$1"
  local host="$2"
  local password="$3"
  local cmd="$4"
  
  if ! command -v sshpass &>/dev/null; then
    log_info "Installing sshpass..."
    sudo apt-get update -yqq && sudo apt-get install -y sshpass || sudo yum install -y sshpass || true
  fi

  SSHPASS="$password" sshpass -e ssh \
    -o StrictHostKeyChecking=no \
    -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no \
    -o ConnectTimeout=15 \
    "${user}@${host}" "$cmd"
}

# Smart SSH exec
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
