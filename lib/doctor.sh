#!/usr/bin/env bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

run_doctor() {
  print_banner "System Diagnostics & Health Check"

  echo -e "\n${BOLD}1. Toolchain & Runtime Versions:${NC}"
  echo -e "   Node       : $(node -v 2>/dev/null || echo "${RED}Not found${NC}")"
  echo -e "   pnpm       : $(pnpm -v 2>/dev/null || echo "${RED}Not found${NC}")"
  echo -e "   PostgreSQL : $(${PSQL_BIN} --version 2>/dev/null || echo "${RED}Not found${NC}")"
  echo -e "   Ollama     : $(ollama -v 2>/dev/null || echo "${YELLOW}Not in PATH (App may be running)${NC}")"

  echo -e "\n${BOLD}2. Applications Health:${NC}"
  for app in $(list_available_apps); do
    load_app_config "$app"
    echo -e "   ${BOLD}${APP_NAME}${NC} (${APP_ID}):"
    echo -e "     Directory : ${APP_DIR} $([ -d "$APP_DIR" ] && echo "${GREEN}✓${NC}" || echo "${RED}✖${NC}")"

    # Port checks
    local api_pid=$(lsof -ti tcp:${API_PORT} 2>/dev/null || true)
    local web_pid=$(lsof -ti tcp:${WEB_PORT} 2>/dev/null || true)
    echo -e "     API Port  : ${API_PORT} $([ -n "$api_pid" ] && echo "${GREEN}ACTIVE (PID ${api_pid})${NC}" || echo "${DIM}IDLE${NC}")"
    echo -e "     Web Port  : ${WEB_PORT} $([ -n "$web_pid" ] && echo "${GREEN}ACTIVE (PID ${web_pid})${NC}" || echo "${DIM}IDLE${NC}")"
    if [ -n "$REALTIME_PORT" ]; then
      local rt_pid=$(lsof -ti tcp:${REALTIME_PORT} 2>/dev/null || true)
      echo -e "     Realtime  : ${REALTIME_PORT} $([ -n "$rt_pid" ] && echo "${GREEN}ACTIVE (PID ${rt_pid})${NC}" || echo "${DIM}IDLE${NC}")"
    fi
    if [ -n "$WORKER_PORT" ]; then
      local wrk_pid=$(lsof -ti tcp:${WORKER_PORT} 2>/dev/null || true)
      echo -e "     Worker    : ${WORKER_PORT} $([ -n "$wrk_pid" ] && echo "${GREEN}ACTIVE (PID ${wrk_pid})${NC}" || echo "${DIM}IDLE${NC}")"
    fi

    # DB Connection check
    if PGPASSWORD=Yuva1213 "${PSQL_BIN}" -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" -d "${DB_NAME}" -c "SELECT 1;" >/dev/null 2>&1; then
      echo -e "     Database  : ${DB_NAME} ${GREEN}✓ CONNECTED${NC}"
    else
      echo -e "     Database  : ${DB_NAME} ${RED}✖ UNREACHABLE${NC}"
    fi

    # Logs
    local today_logs="${LOGS_DIR}/${APP_ID}/latest"
    if [ -d "$today_logs" ]; then
      local log_count=$(find "$today_logs" -type f | wc -l | tr -d ' ')
      echo -e "     Logs      : ${today_logs} (${log_count} files)"
    else
      echo -e "     Logs      : ${DIM}No logs for today${NC}"
    fi
    echo ""
  done
}
