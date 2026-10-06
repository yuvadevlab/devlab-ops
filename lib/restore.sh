#!/usr/bin/env bash
set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"
source "${SOURCE_DIR}/backup.sh"

run_restore() {
  local target_app="$1"
  local target_file="$2"

  load_app_config "$target_app"

  local target_backup_dir="${BACKUPS_DIR}/${APP_ID}"
  if [ ! -d "$target_backup_dir" ]; then
    print_error "No backups found for ${APP_NAME} in ${target_backup_dir}."
    exit 1
  fi

  # Find available snapshots sorted by modification time descending
  local backups=($(find "$target_backup_dir" -type f \( -name "*.sql.gz" -o -name "*.sql" \) | sort -r))
  if [ ${#backups[@]} -eq 0 ]; then
    print_error "No backup files found in ${target_backup_dir}."
    exit 1
  fi

  local selected_file=""
  if [ -n "$target_file" ] && [ -f "$target_file" ]; then
    selected_file="$target_file"
  elif [ -n "$target_file" ] && [ -f "${target_backup_dir}/${target_file}" ]; then
    selected_file="${target_backup_dir}/${target_file}"
  else
    print_banner "${APP_NAME} — Database Restore"
    echo -e "Available database backups in ${DIM}${target_backup_dir}${NC}:\n"
    for i in "${!backups[@]}"; do
      local fname=$(basename "${backups[$i]}")
      local fsize=$(du -h "${backups[$i]}" | cut -f1)
      local fdate=$(date -r "${backups[$i]}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || stat -c "%y" "${backups[$i]}" 2>/dev/null | cut -d'.' -f1)
      echo -e "  [${CYAN}$((i+1))${NC}] ${BOLD}${fname}${NC} (${fsize}) ${DIM}— ${fdate}${NC}"
    done

    echo ""
    read -p "Select backup to restore [1-${#backups[@]}, default: 1]: " selection
    selection=${selection:-1}

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#backups[@]} ]; then
      print_error "Invalid selection: ${selection}"
      exit 1
    fi

    selected_file="${backups[$((selection-1))]}"
  fi

  local fname=$(basename "$selected_file")
  echo -e "\n${YELLOW}⚠️  WARNING: Restoring will overwrite existing data in '${DB_NAME}'.${NC}"
  read -p "Are you sure you want to restore '${fname}'? (yes/N): " confirm
  if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    print_info "Restore cancelled by user."
    exit 0
  fi

  # Safety snapshot before restoring
  echo -e "\n${YELLOW}Step 1/2: Taking safety snapshot of current state before restore...${NC}"
  backup_single_app "$target_app"

  # Terminate active PostgreSQL connections to the database
  echo -e "\n${YELLOW}Step 2/2: Restoring database '${DB_NAME}' from ${fname}...${NC}"
  PGPASSWORD=Yuva1213 "${PSQL_BIN}" -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" -d template1 -c "
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();
  " >/dev/null 2>&1 || true

  if [[ "$selected_file" == *.gz ]]; then
    gunzip -c "$selected_file" | PGPASSWORD=Yuva1213 "${PSQL_BIN}" -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" -d "${DB_NAME}" >/dev/null
  else
    PGPASSWORD=Yuva1213 "${PSQL_BIN}" -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" -d "${DB_NAME}" < "$selected_file" >/dev/null
  fi

  print_success "Database '${DB_NAME}' restored successfully from ${fname}!"
}
