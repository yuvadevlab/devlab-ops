#!/usr/bin/env bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

check_env_drift() {
  local target_app="$1"
  load_app_config "$target_app"

  print_banner "${APP_NAME} — Environment Drift & Secrets Audit"

  local example_files=($(find "$APP_DIR" -maxdepth 4 -name ".env.example" -not -path "*/node_modules/*" 2>/dev/null))
  if [ ${#example_files[@]} -eq 0 ]; then
    print_info "No .env.example files found in ${APP_DIR}."
    return 0
  fi

  local total_missing=0

  for ex in "${example_files[@]}"; do
    local rel_dir=$(dirname "$ex")
    local dir_label=$(basename "$rel_dir")
    local actual_env="${rel_dir}/.env"
    local actual_env_local="${rel_dir}/.env.local"

    if [ ! -f "$actual_env" ] && [ ! -f "$actual_env_local" ]; then
      echo -e "${BOLD}Module: ${dir_label}${NC} (${ex#$APP_DIR/})"
      print_warn "No active .env or .env.local found in ${rel_dir#$APP_DIR/}"
      continue
    fi

    # Extract required keys from .env.example (ignore comments and blank lines)
    local keys=($(grep -E '^[A-Za-z0-9_]+=' "$ex" | cut -d'=' -f1))
    local missing_in_module=0

    echo -e "${BOLD}Module: ${dir_label}${NC} (${ex#$APP_DIR/})"

    for k in "${keys[@]}"; do
      local found=false
      if [ -f "$actual_env" ] && grep -q -E "^${k}=" "$actual_env" 2>/dev/null; then
        found=true
      fi
      if [ -f "$actual_env_local" ] && grep -q -E "^${k}=" "$actual_env_local" 2>/dev/null; then
        found=true
      fi

      if [ "$found" = false ]; then
        echo -e "   ${RED}✖ Missing key:${NC} ${BOLD}${k}${NC}"
        missing_in_module=$((missing_in_module + 1))
        total_missing=$((total_missing + 1))
      fi
    done

    if [ "$missing_in_module" -eq 0 ]; then
      print_success "All $(echo "${#keys[@]}") environment variables verified for ${dir_label}"
    else
      echo -e "   ${YELLOW}⚠ ${missing_in_module} missing variable(s) compared to template.${NC}"
    fi
    echo ""
  done

  if [ "$total_missing" -eq 0 ]; then
    print_success "Environment integrity check passed! Zero missing secrets."
  else
    print_warn "Found ${total_missing} missing variable(s). Review before starting services."
  fi
}
