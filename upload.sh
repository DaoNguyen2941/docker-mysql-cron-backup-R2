#!/bin/bash
set -e

# ====== OPTIONAL UPLOAD ENABLE FLAG ======
if [ -z "${ENABLE_UPLOAD}" ] || [ "${ENABLE_UPLOAD}" != "true" ]; then
  echo "⚙️  Upload step skipped (ENABLE_UPLOAD not set to 'true')."
  exit 0
fi

# ====== READ SECRETS (same style as backup.sh) ======
# Get access key id
[ -z "${R2_ACCESS_KEY_ID_FILE}" ] || { R2_ACCESS_KEY_ID=$(head -1 "${R2_ACCESS_KEY_ID_FILE}"); }
[ -z "${R2_ACCESS_KEY_ID}" ] && { echo "=> R2_ACCESS_KEY_ID cannot be empty" && exit 1; }

# Get secret access key
[ -z "${R2_SECRET_ACCESS_KEY_FILE}" ] || { R2_SECRET_ACCESS_KEY=$(head -1 "${R2_SECRET_ACCESS_KEY_FILE}"); }
[ -z "${R2_SECRET_ACCESS_KEY}" ] && { echo "=> R2_SECRET_ACCESS_KEY cannot be empty" && exit 1; }

# Get bucket name
[ -z "${R2_BUCKET_FILE}" ] || { R2_BUCKET=$(head -1 "${R2_BUCKET_FILE}"); }
[ -z "${R2_BUCKET}" ] && { echo "=> R2_BUCKET cannot be empty" && exit 1; }

# Get account id
[ -z "${R2_ACCOUNT_ID_FILE}" ] || { R2_ACCOUNT_ID=$(head -1 "${R2_ACCOUNT_ID_FILE}"); }
[ -z "${R2_ACCOUNT_ID}" ] && { echo "=> R2_ACCOUNT_ID cannot be empty" && exit 1; }

# Get endpoint (optional; auto-generate if missing)
[ -z "${R2_ENDPOINT_FILE}" ] || { R2_ENDPOINT=$(head -1 "${R2_ENDPOINT_FILE}"); }
[ -z "${R2_ENDPOINT}" ] && [ -n "${R2_ACCOUNT_ID}" ] && R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
[ -z "${R2_ENDPOINT}" ] && { echo "=> R2_ENDPOINT cannot be empty" && exit 1; }

# ====== CONFIG ======
BACKUP_DIR="/backup"
RCLONE_CONF="/root/.config/rclone/rclone.conf"
REMOTE_NAME="r2remote"
LOG_FILE="/mysql_backup_upload.log"

echo "====================================================="
echo "🚀 Starting Cloudflare R2 upload process..."
echo "📅 Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "====================================================="

# ====== CHECK DEPENDENCIES ======
if ! command -v rclone &> /dev/null; then
  echo "❌ ERROR: 'rclone' not found! Please install it in the container."
  exit 1
fi

# ====== SHOW CONFIG (masked) ======
echo "🔐 Cloudflare R2 configuration:"
echo "   • Endpoint: ${R2_ENDPOINT}"
echo "   • Bucket:   ${R2_BUCKET}"
echo "   • AccessKey: ${R2_ACCESS_KEY_ID:0:6}********"
echo "====================================================="

# ====== CREATE RCLONE CONFIG ======
mkdir -p "$(dirname "$RCLONE_CONF")"

cat > "$RCLONE_CONF" <<EOF
[$REMOTE_NAME]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = ${R2_ENDPOINT}
region = auto
EOF

echo "✅ rclone config generated at: $RCLONE_CONF"

# ====== VERIFY BACKUP DIRECTORY ======
if [ ! -d "$BACKUP_DIR" ]; then
  echo "❌ Backup directory not found: $BACKUP_DIR"
  exit 1
fi

FILE_COUNT=$(find "$BACKUP_DIR" -type f -name "*.sql.gz" | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
  echo "⚠️  No backup files found in $BACKUP_DIR. Nothing to upload."
  exit 0
fi

echo "📦 Found $FILE_COUNT backup file(s) to sync."
echo "====================================================="

# ====== UPLOAD TO R2 ======
echo "⬆️  Uploading new backup files to R2 bucket..."
rclone copy "$BACKUP_DIR" ${REMOTE_NAME}:${R2_BUCKET}/mysql-backups \
  --progress \
  --ignore-existing \
  --log-file "$LOG_FILE" \
  --log-level INFO

echo "====================================================="
echo "✅ Upload completed successfully at $(date '+%Y-%m-%d %H:%M:%S')"
echo "📝 Logs written to: $LOG_FILE"
echo "====================================================="
