#!/bin/bash
# ============================================================
# Module: MinIO Transfer - Interactive Upload/Download
# Fungsi: Transfer file/folder antara Local dan MinIO
# ============================================================
set -e

# Load shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
source "$SCRIPT_DIR/../../lib/minio.sh"

print_banner "MinIO Transfer (mc-client)"

# ─── 1. Prerequisite: Ensure mc is installed ───
ensure_mc_installed

# ─── 2. Setup MinIO Alias ───
print_section "MinIO Connection"
read -rp "  MinIO alias (contoh: btu-storage): " MINIO_ALIAS
[[ -z "$MINIO_ALIAS" ]] && { log_error "Alias tidak boleh kosong"; exit 1; }

setup_minio_alias "$MINIO_ALIAS"

# ─── 3. Action Menu ───
echo ""
echo "  Pilih Aksi:"
echo "    1)  Download (S3 ➜ Local)"
echo "    2)  Upload   (Local ➜ S3)"
echo "    3)  Mirror / Sync Folder (Local ➜ S3)"
read -rp "  Pilihan [1/2/3]: " ACTION

case $ACTION in
  1)
    # ─── DOWNLOAD ───
    print_section "Download (S3 ➜ Local)"
    
    read -rp "  Masukkan Bucket/Prefix (contoh: bucket-file/backups): " BUCK_PREFIX
    FULL_S3_PATH="${MINIO_ALIAS}/${BUCK_PREFIX}"
    
    log_info "Listing available files in ${FULL_S3_PATH}:"
    echo ""
    "$MC_CMD" ls "${FULL_S3_PATH}/" || { log_error "Gagal membaca bucket"; exit 1; }
    echo ""
    
    read -rp "  Nama file yang mau didownload (pisahkan koma jika > 1): " FILE_INPUT
    read -rp "  Destinasi lokal [$HOME/downloads]: " LOCAL_DEST
    LOCAL_DEST=${LOCAL_DEST:-$HOME/downloads}
    mkdir -p "$LOCAL_DEST"

    IFS=',' read -ra FILES <<< "$FILE_INPUT"
    for f in "${FILES[@]}"; do
      f=$(echo "$f" | xargs)
      [[ -z "$f" ]] && continue
      log_step "Downloading: $f"
      minio_download "${FULL_S3_PATH}/$f" "$LOCAL_DEST/"
    done
    ;;

  2)
    # ─── UPLOAD ───
    print_section "Upload (Local ➜ S3)"
    
    read -rp "  Path Lokal (folder sumber, contoh: /home/devops): " LOCAL_SOURCE
    [[ ! -d "$LOCAL_SOURCE" ]] && { log_error "Folder lokal tidak ditemukan"; exit 1; }
    
    log_info "Isi folder ${LOCAL_SOURCE}:"
    ls -1 "$LOCAL_SOURCE" | head -20
    echo ""
    
    read -rp "  Nama file yang mau diupload (pisahkan koma jika > 1): " FILE_INPUT
    read -rp "  Target Bucket/Prefix (contoh: bucket-file/uploads): " BUCK_PREFIX
    FULL_S3_PATH="${MINIO_ALIAS}/${BUCK_PREFIX}"

    ensure_bucket "$FULL_S3_PATH"

    IFS=',' read -ra FILES <<< "$FILE_INPUT"
    for f in "${FILES[@]}"; do
      f=$(echo "$f" | xargs)
      [[ -z "$f" ]] && continue
      LOCAL_FILE="${LOCAL_SOURCE}/$f"
      
      if [[ ! -f "$LOCAL_FILE" ]]; then
        log_warn "File tidak ditemukan: $LOCAL_FILE, skipping..."
        continue
      fi
      
      log_step "Uploading: $f"
      minio_upload "$LOCAL_FILE" "${FULL_S3_PATH}/"
    done
    ;;

  3)
    # ─── MIRROR / SYNC ───
    print_section "Mirror / Sync (Local ➜ S3)"
    
    read -rp "  Folder Lokal Sumber: " LOCAL_SOURCE
    [[ ! -d "$LOCAL_SOURCE" ]] && { log_error "Folder lokal tidak ditemukan"; exit 1; }
    
    read -rp "  Target MinIO (contoh: bucket-file/web-sync): " BUCK_PREFIX
    FULL_S3_PATH="${MINIO_ALIAS}/${BUCK_PREFIX}"
    
    ensure_bucket "$FULL_S3_PATH"
    
    log_info "Memulai mirror $LOCAL_SOURCE ke $FULL_S3_PATH ..."
    "$MC_CMD" mirror --overwrite "$LOCAL_SOURCE" "${FULL_S3_PATH}/"
    log_ok "Sync selesai!"
    ;;

  *)
    log_error "Pilihan tidak valid"
    exit 1
    ;;
esac

echo ""
log_ok "🎉 Operasi MinIO selesai!"
echo ""
