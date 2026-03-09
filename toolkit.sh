#!/bin/bash
# ============================================================
# DevOps Toolkit - Main Entry Point
# Satu menu untuk semua automation tools
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

show_menu() {
  clear
  echo ""
  echo "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo "${CYAN}${BOLD}║                                                          ║${RESET}"
  echo "${CYAN}${BOLD}║   🛠️   DevOps Toolkit v1.0                               ║${RESET}"
  echo "${CYAN}${BOLD}║   Your all-in-one DevOps automation scripts              ║${RESET}"
  echo "${CYAN}${BOLD}║                                                          ║${RESET}"
  echo "${CYAN}${BOLD}╠══════════════════════════════════════════════════════════╣${RESET}"
  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}  ${GREEN}${BOLD}KUBERNETES${RESET}                                             ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    1)  Setup Kubernetes Cluster (KubeKey)                 ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    2)  Install KubeSphere Dashboard                       ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}  ${YELLOW}${BOLD}VELERO BACKUP${RESET}                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    3)  Install Velero + Backup                            ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    4)  Backup Only (Velero sudah ada)                     ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    5)  Restore Namespace                                  ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}  ${MAGENTA}${BOLD}SERVER BACKUP${RESET}                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    6)  Backup Server Config → MinIO                       ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    7)  Restore Server Config ← MinIO                      ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}  ${BLUE}${BOLD}PROVISIONING${RESET}                                           ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    8)  Provisioning Server Baru                           ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}  ${MAGENTA}${BOLD}AZURE DEVOPS${RESET}                                            ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    9)  Install Azure DevOps Agent                         ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}  ${YELLOW}${BOLD}DATABASE${RESET}                                                ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    11) Enable SQL Server Agent                            ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}  ${GREEN}${BOLD}TOOLS${RESET}                                                   ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    12) MinIO Transfer (Upload/Download)                   ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}║${RESET}    0)  Exit                                               ${CYAN}${BOLD}║${RESET}"

  echo "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
  echo "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

run_module() {
  local module="$1"
  local module_path="$SCRIPT_DIR/modules/$module"

  if [[ ! -f "$module_path" ]]; then
    log_error "Module not found: $module_path"
    return 1
  fi

  bash "$module_path"
}

# ─── Main Loop ───
while true; do
  show_menu
  read -rp "  ${WHITE}${BOLD}Pilih menu [0-12]: ${RESET}" choice

  case $choice in
    1) run_module "kubernetes/install-kubekey.sh" ;;
    2) run_module "kubernetes/install-kubesphere.sh" ;;
    3) run_module "velero/install.sh" ;;
    4) run_module "velero/backup.sh" ;;
    5) run_module "velero/restore.sh" ;;
    6) run_module "backup-server/backup.sh" ;;
    7) run_module "backup-server/restore.sh" ;;
    8) run_module "provisioning/provisioning.sh" ;;
    9) run_module "azure/install-agent.sh" ;;
    11) run_module "database/enable-sql-agent.sh" ;;
    12) run_module "minio/transfer.sh" ;;
    0)
      echo ""
      log_ok "Bye! Happy DevOps 🚀"
      echo ""
      exit 0
      ;;
    *)
      log_error "Pilihan tidak valid"
      ;;
  esac

  echo ""
  read -rp "  ${CYAN}Tekan ENTER untuk kembali ke menu...${RESET}"
done
