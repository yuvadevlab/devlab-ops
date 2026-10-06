#!/usr/bin/env bash
set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

backup_single_app() {
  local app_id="$1"
  load_app_config "$app_id"

  local target_backup_dir="${BACKUPS_DIR}/${APP_ID}"
  mkdir -p "$target_backup_dir"

  local timestamp=$(date +"${DEFAULT_TIMESTAMP_FORMAT}")
  local backup_file="${target_backup_dir}/${APP_ID}_${timestamp}.sql.gz"

  echo -e "📦 Backing up ${BOLD}${APP_NAME}${NC} database ('${DB_NAME}')..."
  PGPASSWORD=Yuva1213 "${PG_DUMP_BIN}" -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" -d "${DB_NAME}" | gzip > "$backup_file"
  local file_size=$(du -h "$backup_file" | cut -f1)
  print_success "Saved: ${backup_file} (${file_size})"

  # Retention Pruning
  echo -e "🧹 Pruning backups older than ${RETENTION_DAYS} days in ${target_backup_dir}..."
  find "$target_backup_dir" -type f \( -name "*.sql" -o -name "*.sql.gz" \) -mtime +"${RETENTION_DAYS}" -exec rm -f {} + 2>/dev/null || true
}

run_backup() {
  local target="${1:-all}"
  local today=$(date +"${DEFAULT_DATE_FORMAT}")

  print_banner "Database Backup (${today})"
  echo -e "Retention Policy: Keep last ${BOLD}${RETENTION_DAYS} days${NC}\n"

  if [ "$target" = "all" ]; then
    for app in $(list_available_apps); do
      backup_single_app "$app"
      echo ""
    done
  else
    backup_single_app "$target"
  fi

  print_success "Backup routine finished."
}
