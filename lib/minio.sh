#!/bin/bash
# ============================================================
# DevOps Toolkit - MinIO Shared Library
# Fungsi-fungsi reusable untuk integrasi MinIO
# ============================================================

[[ -n "$_LIB_MINIO_LOADED" ]] && return 0
_LIB_MINIO_LOADED=1

# Load common library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# ─── Default config ───
MC_BIN="/usr/local/bin/mc"
MC_URL="https://dl.min.io/client/mc/release/linux-amd64/mc"
MC_CMD="$MC_BIN"

# ─── Install MinIO Client jika belum ada ───
ensure_mc_installed() {
  log_info "Checking MinIO Client (mc)..."

  if [[ -x "$MC_BIN" ]]; then
    log_ok "MinIO Client already installed"
    return 0
  fi

  log_warn "MinIO Client not found, installing..."

  if ! command -v sudo >/dev/null 2>&1; then
    log_error "sudo is required to install mc"
    exit 1
  fi

  # Auto-detect architecture
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64)  MC_URL="https://dl.min.io/client/mc/release/linux-amd64/mc" ;;
    aarch64) MC_URL="https://dl.min.io/client/mc/release/linux-arm64/mc" ;;
    *)       log_error "Unsupported architecture: $arch"; exit 1 ;;
  esac

  wget -q "$MC_URL" -O /tmp/mc
  chmod +x /tmp/mc
  sudo mv /tmp/mc "$MC_BIN"

  log_ok "MinIO Client installed at $MC_BIN"
}

# ─── Cek dan setup MinIO alias ───
# Usage: setup_minio_alias "alias-name"
setup_minio_alias() {
  local alias_name="$1"

  log_info "Checking MinIO alias '${alias_name}'..."

  local need_config=false

  if "$MC_CMD" alias ls 2>/dev/null | awk '{print $1}' | grep -qx "${alias_name}"; then
    log_info "Alias '${alias_name}' exists, testing connection..."

    if "$MC_CMD" ls "${alias_name}" >/dev/null 2>&1; then
      log_ok "MinIO credential valid"
    else
      log_warn "Alias exists but credential INVALID"
      need_config=true
    fi
  else
    log_warn "Alias '${alias_name}' not found"
    need_config=true
  fi

  if [[ "$need_config" == true ]]; then
    log_info "Please input MinIO configuration"

    local endpoint access_key secret_key
    read -rp "  MinIO Endpoint   : " endpoint
    read -rp "  MinIO Access Key : " access_key
    read -rsp "  MinIO Secret Key : " secret_key
    echo ""

    "$MC_CMD" alias set \
      "$alias_name" \
      "$endpoint" \
      "$access_key" \
      "$secret_key"

    log_ok "Alias '${alias_name}' configured successfully"
  fi
}

# ─── Ensure bucket exists ───
# Usage: ensure_bucket "alias/bucket-name"
ensure_bucket() {
  local bucket_path="$1"

  log_info "Checking bucket '${bucket_path}'..."

  if "$MC_CMD" ls "${bucket_path}" >/dev/null 2>&1; then
    log_ok "Bucket exists"
  else
    log_info "Creating bucket..."
    "$MC_CMD" mb "${bucket_path}"
    log_ok "Bucket created"
  fi
}

# ─── Upload file ke MinIO ───
# Usage: minio_upload "local-file" "alias/bucket/prefix/"
minio_upload() {
  local local_file="$1"
  local target="$2"

  if [[ ! -f "$local_file" ]]; then
    log_error "File tidak ditemukan untuk diupload: $local_file"
    exit 1
  fi

  log_info "Uploading to MinIO: ${target}"
  if "$MC_CMD" cp "$local_file" "${target}"; then
    log_ok "Upload success!"
  else
    log_error "Gagal upload ke MinIO. Cek koneksi atau kuota storage."
    exit 1
  fi
}

# ─── Download file dari MinIO ───
# Usage: minio_download "alias/bucket/prefix/file" "local-path"
minio_download() {
  local source="$1"
  local local_path="$2"

  log_info "Downloading from MinIO..."
  "$MC_CMD" cp "$source" "$local_path"
  log_ok "Download complete: $local_path"
}
