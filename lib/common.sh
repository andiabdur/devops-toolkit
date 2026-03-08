#!/bin/bash
# ============================================================
# DevOps Toolkit - Common Shared Library
# Fungsi-fungsi reusable untuk semua module
# ============================================================

# ─── Prevent double-source ───
[[ -n "$_LIB_COMMON_LOADED" ]] && return 0
_LIB_COMMON_LOADED=1

# ─── Colors ───
if [[ -t 1 ]]; then
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  WHITE=$(tput setaf 7)
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
else
  RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE="" BOLD="" RESET=""
fi

# ─── Resolve LIB and ROOT directory ───
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$LIB_DIR/.." && pwd)"

# ─── Logging ───
log_info()    { echo "${CYAN}${BOLD}[INFO]${RESET}  $1"; }
log_ok()      { echo "${GREEN}${BOLD}[OK]${RESET}    $1"; }
log_warn()    { echo "${YELLOW}${BOLD}[WARN]${RESET}  $1"; }
log_error()   { echo "${RED}${BOLD}[ERROR]${RESET} $1"; }
log_step()    { echo "${BLUE}${BOLD}[STEP]${RESET}  $1"; }

# ─── Banner ───
print_banner() {
  local title="${1:-DevOps Toolkit}"
  echo ""
  echo "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
  printf "${CYAN}${BOLD}║${RESET}  🛠️  %-44s ${CYAN}${BOLD}║${RESET}\n" "$title"
  echo "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
}

# ─── Section divider ───
print_section() {
  echo ""
  echo "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo "${BLUE}${BOLD}  $1${RESET}"
  echo "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# ─── Validasi IP ───
validate_ip() {
  local ip=$1
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -ra octets <<< "$ip"
    for o in "${octets[@]}"; do
      (( o > 255 )) && return 1
    done
    return 0
  fi
  return 1
}

# ─── Cek dependency command ───
require_command() {
  local cmd=$1
  local install_hint=${2:-""}
  if ! command -v "$cmd" &>/dev/null; then
    log_error "'$cmd' is required but not installed."
    [[ -n "$install_hint" ]] && log_info "Install with: $install_hint"
    exit 1
  fi
}

# ─── Konfirmasi yes/no ───
confirm() {
  local msg=${1:-"Continue?"}
  read -rp "${YELLOW}${BOLD}$msg (y/n): ${RESET}" answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ─── Konfirmasi yes (explicit) ──
confirm_yes() {
  local msg=${1:-"Continue?"}
  read -rp "${YELLOW}${BOLD}$msg (yes/no): ${RESET}" answer
  [[ "$answer" == "yes" ]]
}

# ─── Countdown timer ───
countdown() {
  local seconds=${1:-5}
  local msg=${2:-"Starting in"}
  for (( i=seconds; i>=1; i-- )); do
    echo -ne "${CYAN}⏳ $msg $i seconds...\r${RESET}"
    sleep 1
  done
  echo ""
}

# ─── Timestamp ISO ───
timestamp() {
  date +"%Y%m%d"
}

timestamp_full() {
  date +"%Y%m%d-%H%M%S"
}
