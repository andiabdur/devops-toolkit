#!/bin/bash
# ============================================================
# Module: Velero - Install / Patch + Backup
# Fungsi: Install Velero CLI, setup MinIO backend, run backup
# ============================================================
set -e

# Load shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

print_banner "Velero Install / Patch + Backup"

# ─── User Input Config ───
print_section "Velero Configuration"

read -rp "  Namespace Velero [velero]: " VELERO_NS
VELERO_NS=${VELERO_NS:-velero}

read -rp "  MinIO S3 Endpoint [https://nos.jkt-1.neo.id]: " S3_ENDPOINT
S3_ENDPOINT=${S3_ENDPOINT:-https://nos.jkt-1.neo.id}

read -rp "  Nama Bucket [bucket-file]: " BUCKET
BUCKET=${BUCKET:-bucket-file}

read -rp "  Prefix Backup [velero-backup]: " PREFIX
PREFIX=${PREFIX:-velero-backup}

read -rp "  Access Key: " ACCESS_KEY
read -s -rp "  Secret Key: " SECRET_KEY
echo ""

# ─── Precheck ───
print_section "Pre-check"
require_command "kubectl" "Install kubectl: https://kubernetes.io/docs/tasks/tools/"

# ─── Install Velero CLI ───
print_section "Velero CLI"

if command -v velero &>/dev/null; then
  log_ok "Velero CLI sudah ada → $(velero version --client-only 2>/dev/null | head -1)"
else
  log_info "Velero CLI belum ada, installing latest..."

  VELERO_VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f 4)

  log_info "Velero version: ${VELERO_VERSION}"

  curl -L "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz" \
    | tar -xz

  sudo mv "velero-${VELERO_VERSION}-linux-amd64/velero" /usr/local/bin/velero
  sudo chmod +x /usr/local/bin/velero

  # Cleanup extracted directory
  rm -rf "velero-${VELERO_VERSION}-linux-amd64"

  log_ok "Velero CLI installed"
fi

# ─── Detect Velero Server ───
print_section "Detect Velero Server"

if kubectl get ns "${VELERO_NS}" &>/dev/null && \
   kubectl -n "${VELERO_NS}" get deploy velero &>/dev/null 2>&1; then
  MODE="patch"
  log_info "Velero SERVER terdeteksi → ${GREEN}MODE PATCH${RESET}"
else
  MODE="install"
  log_info "Velero SERVER belum ada → ${YELLOW}MODE INSTALL${RESET}"
fi

# ─── Create Credential File ───
CRED_FILE=$(mktemp /tmp/credentials-velero.XXXXXX)
cat <<EOF > "$CRED_FILE"
[default]
aws_access_key_id=${ACCESS_KEY}
aws_secret_access_key=${SECRET_KEY}
EOF

# Ensure credential file is always cleaned up
trap "rm -f '$CRED_FILE'" EXIT

# ─── Install Mode ───
if [[ "$MODE" == "install" ]]; then
  print_section "Installing Velero"

  velero install \
    --namespace "${VELERO_NS}" \
    --provider aws \
    --plugins velero/velero-plugin-for-aws \
    --bucket "${BUCKET}" \
    --prefix "${PREFIX}" \
    --secret-file "$CRED_FILE" \
    --use-volume-snapshots=false \
    --backup-location-config "region=minio,s3ForcePathStyle=true,s3Url=${S3_ENDPOINT}"

  log_ok "Velero installed successfully"
fi

# ─── Patch Mode ───
if [[ "$MODE" == "patch" ]]; then
  print_section "Patching Velero"

  kubectl -n "${VELERO_NS}" apply -f - <<EOF
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: ${VELERO_NS}
spec:
  provider: aws
  objectStorage:
    bucket: ${BUCKET}
    prefix: ${PREFIX}
  config:
    region: minio
    s3ForcePathStyle: "true"
    s3Url: ${S3_ENDPOINT}
EOF

  kubectl -n "${VELERO_NS}" delete secret cloud-credentials --ignore-not-found
  kubectl -n "${VELERO_NS}" create secret generic cloud-credentials \
    --from-file=cloud="$CRED_FILE"

  log_ok "Velero patched successfully"
fi

# ─── Restart & Validate ───
print_section "Restart & Validate"

kubectl -n "${VELERO_NS}" rollout restart deploy/velero
kubectl -n "${VELERO_NS}" rollout status deploy/velero

echo ""
log_info "Backup Storage Locations:"
kubectl -n "${VELERO_NS}" get backupstoragelocation
echo ""
log_info "Available namespaces:"
kubectl get namespaces
echo ""

# ─── Backup Section ───
print_section "Backup"

read -rp "  Namespace yang mau dibackup (pisahkan koma / ketik all): " INPUT_NS
read -rp "  Nama server ini (contoh: btu-cp-01): " INPUT_HOST

TIMESTAMP=$(timestamp)

if [[ "$INPUT_NS" == "all" ]]; then
  BACKUP_NAME="backup-all-${INPUT_HOST}-${TIMESTAMP}"
  log_info "Membuat backup SEMUA namespace: ${BACKUP_NAME}"
  velero backup create "${BACKUP_NAME}" --wait
else
  IFS=',' read -ra NS_LIST <<< "$INPUT_NS"

  for NS in "${NS_LIST[@]}"; do
    NS=$(echo "$NS" | xargs)

    # Validate namespace exists
    if ! kubectl get ns "$NS" &>/dev/null; then
      log_warn "Namespace '$NS' tidak ditemukan, skip..."
      continue
    fi

    BACKUP_NAME="backup-${NS}-${INPUT_HOST}-${TIMESTAMP}"
    log_info "Membuat backup namespace: ${NS}"
    velero backup create "${BACKUP_NAME}" \
      --include-namespaces "${NS}" \
      --wait
  done
fi

echo ""
log_ok "🎉 SEMUA BACKUP SELESAI!"
echo ""
velero backup get
