#!/usr/bin/env bash
set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

sync_prod_to_dev() {
  local target_app="$1"
  local flag="$2"

  if [ -z "$target_app" ]; then
    print_error "No application specified."
    echo -e "Usage: devlab sync-db <app> [-y]"
    echo -e "Available apps: $(list_available_apps)"
    exit 1
  fi

  load_app_config "$target_app"

  local dev_db="${DEV_DB_NAME:-${DB_NAME}_dev}"
  local psql_auth="PGPASSWORD=Yuva1213"

  print_banner "${APP_NAME} — Sync Production DB to Dev"
  echo -e "   Source (Production)  : ${YELLOW}${DB_NAME}${NC} (Port ${DB_PORT})"
  echo -e "   Target (Development) : ${GREEN}${dev_db}${NC} (Port ${DB_PORT})"
  echo -e "   Database Host        : ${DB_HOST}"
  echo -e "${BOLD}${CYAN}------------------------------------------------------${NC}"

  # Verify PostgreSQL client binaries
  if [ ! -x "$PSQL_BIN" ] && ! command -v psql >/dev/null 2>&1; then
    print_error "psql client not found. Ensure PostgreSQL is installed."
    exit 1
  fi
  if [ ! -x "$PG_DUMP_BIN" ] && ! command -v pg_dump >/dev/null 2>&1; then
    print_error "pg_dump client not found. Ensure PostgreSQL is installed."
    exit 1
  fi

  # Verify source database connectivity
  if ! eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d template1 -c \"SELECT 1;\"" >/dev/null 2>&1; then
    print_error "Cannot connect to PostgreSQL server at ${DB_HOST}:${DB_PORT}."
    exit 1
  fi

  # Check if source production DB exists
  local source_exists=$(eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d template1 -tAc \"SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';\"" 2>/dev/null || true)
  if [ "$source_exists" != "1" ]; then
    print_error "Production database '${DB_NAME}' does not exist on PostgreSQL."
    exit 1
  fi

  # Confirm destructive operation on dev DB
  if [ "$flag" != "-y" ] && [ "$flag" != "--yes" ] && [ "$flag" != "--force" ]; then
    echo -e "\n${YELLOW}⚠️  WARNING: This will completely replace data in '${dev_db}' with a fresh clone of '${DB_NAME}'.${NC}"
    read -p "Are you sure you want to overwrite '${dev_db}'? (yes/N): " confirm
    if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
      print_info "Sync cancelled by user."
      exit 0
    fi
  fi

  # Check if dev DB exists, create if missing
  local dev_exists=$(eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d template1 -tAc \"SELECT 1 FROM pg_database WHERE datname='${dev_db}';\"" 2>/dev/null || true)
  if [ "$dev_exists" != "1" ]; then
    echo -e "\n${CYAN}ℹ Creating development database '${dev_db}'...${NC}"
    eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d template1 -c \"CREATE DATABASE ${dev_db} OWNER ${DB_USER};\"" >/dev/null
    print_success "Created database '${dev_db}'."
  else
    # Step 1: Pre-sync safety snapshot of existing dev DB (keep last 5)
    echo -e "\n${CYAN}Step 1/3: Taking safety snapshot of current '${dev_db}'...${NC}"
    local dev_backup_dir="${BACKUPS_DIR}/${APP_ID}/dev_snapshots"
    mkdir -p "$dev_backup_dir"
    local timestamp=$(date +"${DEFAULT_TIMESTAMP_FORMAT}")
    local dev_backup_file="${dev_backup_dir}/${dev_db}_pre_sync_${timestamp}.sql.gz"
    eval "${psql_auth} \"${PG_DUMP_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d \"${dev_db}\"" 2>/dev/null | gzip > "$dev_backup_file" || true
    if [ -f "$dev_backup_file" ] && [ -s "$dev_backup_file" ]; then
      local bsize=$(du -h "$dev_backup_file" | cut -f1)
      print_success "Saved safety snapshot: $(basename "$dev_backup_file") (${bsize})"
      # Keep only 5 most recent snapshots
      ls -t "${dev_backup_dir}"/* 2>/dev/null | tail -n +6 | xargs -I {} rm -f "{}" 2>/dev/null || true
    fi
  fi

  # Step 2: Terminate active connections & reset schema in dev DB
  echo -e "\n${CYAN}Step 2/3: Resetting development database '${dev_db}'...${NC}"
  eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d template1 -c \"
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${dev_db}' AND pid <> pg_backend_pid();
  \"" >/dev/null 2>&1 || true

  eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d \"${dev_db}\" -c \"
    DROP SCHEMA public CASCADE;
    CREATE SCHEMA public;
    GRANT ALL ON SCHEMA public TO ${DB_USER};
  \"" >/dev/null 2>&1
  print_success "Schema in '${dev_db}' reset cleanly."

  # Step 3: Stream clone directly from prod to dev
  echo -e "\n${CYAN}Step 3/3: Cloning data from '${DB_NAME}' into '${dev_db}'...${NC}"
  eval "${psql_auth} \"${PG_DUMP_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" --no-owner --no-privileges -d \"${DB_NAME}\"" | \
    eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d \"${dev_db}\"" >/dev/null 2>&1

  # Verification
  local prod_tables=$(eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d \"${DB_NAME}\" -tAc \"SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';\"" 2>/dev/null || echo "0")
  local dev_tables=$(eval "${psql_auth} \"${PSQL_BIN}\" -U \"${DB_USER}\" -h \"${DB_HOST}\" -p \"${DB_PORT}\" -d \"${dev_db}\" -tAc \"SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';\"" 2>/dev/null || echo "0")

  echo ""
  if [ "$dev_tables" -eq "$prod_tables" ] && [ "$dev_tables" -gt 0 ]; then
    print_success "Production clone completed successfully!"
    echo -e "   Verified Tables : ${BOLD}${dev_tables}/${prod_tables}${NC} tables cloned"
    echo -e "   Target Database : ${GREEN}${dev_db}${NC} is up to date and ready for local development testing."
  else
    print_warn "Cloned ${dev_tables} tables (production has ${prod_tables} tables). Verify with psql if needed."
  fi
}
