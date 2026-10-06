#!/usr/bin/env bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

tail_logs() {
  local target_app="$1"
  local stream="${2:-e2e}"

  load_app_config "$target_app"

  local target_dir="${LOGS_DIR}/${APP_ID}/latest"
  if [ ! -d "$target_dir" ]; then
    print_error "No logs found for ${APP_NAME} in ${target_dir}."
    echo -e "Start the application first: ${BOLD}./devlab start ${APP_ID}${NC}"
    exit 1
  fi

  case "$stream" in
    e2e|all-stream)
      echo -e "${BOLD}${CYAN}🔍 [${APP_NAME}] Tailing Master E2E Stream... (Ctrl+C to exit)${NC}"
      tail -f "${target_dir}/e2e.log"
      ;;
    error|err|errors)
      echo -e "${BOLD}${RED}🚨 [${APP_NAME}] Tailing Master Errors... (Ctrl+C to exit)${NC}"
      tail -f "${target_dir}/error.log"
      ;;
    api)
      echo -e "${BOLD}${CYAN}🔍 [${APP_NAME}] Tailing API Logs... (Ctrl+C to exit)${NC}"
      tail -f "${target_dir}/api/api.log"
      ;;
    web)
      echo -e "${BOLD}${GREEN}🔍 [${APP_NAME}] Tailing Web Logs... (Ctrl+C to exit)${NC}"
      tail -f "${target_dir}/web/web.log"
      ;;
    http|access)
      echo -e "${BOLD}${YELLOW}🌐 [${APP_NAME}] Tailing HTTP Traffic... (Ctrl+C to exit)${NC}"
      tail -f "${target_dir}/api/http.log"
      ;;
    api-error)
      echo -e "${BOLD}${RED}🚨 [${APP_NAME}] Tailing API Error Stream... (Ctrl+C to exit)${NC}"
      tail -f "${target_dir}/api/error.log"
      ;;
    web-error)
      echo -e "${BOLD}${RED}🚨 [${APP_NAME}] Tailing Web Error Stream... (Ctrl+C to exit)${NC}"
      tail -f "${target_dir}/web/error.log"
      ;;
    list|*)
      echo -e "${BOLD}📋 [${APP_NAME}] Log Files for Today (${target_dir}):${NC}"
      ls -lh "${target_dir}" "${target_dir}/api" "${target_dir}/web" 2>/dev/null || true
      echo -e "\n${DIM}Usage: ./devlab logs ${APP_ID} [e2e | error | api | web | http]${NC}"
      ;;
  esac
}
