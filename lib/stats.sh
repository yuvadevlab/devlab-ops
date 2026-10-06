#!/usr/bin/env bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

show_stats() {
  print_banner "Storage & Operational Metrics"

  echo -e "\n${BOLD}1. Database Backup Snapshots:${NC}"
  for app in $(list_available_apps); do
    load_app_config "$app"
    local bdir="${BACKUPS_DIR}/${APP_ID}"
    if [ -d "$bdir" ]; then
      local count=$(find "$bdir" -type f \( -name "*.sql" -o -name "*.sql.gz" \) | wc -l | tr -d ' ')
      local bsize=$(du -sh "$bdir" 2>/dev/null | cut -f1)
      local latest_backup=$(ls -t "$bdir" 2>/dev/null | head -n 1)
      echo -e "   ${BOLD}${APP_NAME}${NC}: ${count} snapshots (${bsize}) ${DIM}| Latest: ${latest_backup:-none}${NC}"
    else
      echo -e "   ${BOLD}${APP_NAME}${NC}: 0 snapshots"
    fi
  done

  echo -e "\n${BOLD}2. Date-Partitioned Logs:${NC}"
  for app in $(list_available_apps); do
    load_app_config "$app"
    local ldir="${LOGS_DIR}/${APP_ID}"
    if [ -d "$ldir" ]; then
      local day_count=$(find "$ldir" -mindepth 1 -maxdepth 1 -type d -name "20*" | wc -l | tr -d ' ')
      local lsize=$(du -sh "$ldir" 2>/dev/null | cut -f1)
      echo -e "   ${BOLD}${APP_NAME}${NC}: ${day_count} date partition(s) (${lsize})"
    else
      echo -e "   ${BOLD}${APP_NAME}${NC}: 0 log partitions"
    fi
  done

  echo -e "\n${BOLD}3. Overall Production Footprint:${NC}"
  local total_backups=$(du -sh "${BACKUPS_DIR}" 2>/dev/null | cut -f1 || echo "0B")
  local total_logs=$(du -sh "${LOGS_DIR}" 2>/dev/null | cut -f1 || echo "0B")
  echo -e "   Total Backups Storage : ${CYAN}${total_backups}${NC}"
  echo -e "   Total Logs Storage    : ${GREEN}${total_logs}${NC}"
  echo ""
}
