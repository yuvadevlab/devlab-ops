#!/usr/bin/env bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

run_guard() {
  local target_app="$1"
  load_app_config "$target_app"

  local guard_dir="${REPOS_DIR}/devlab-guard"
  if [ ! -f "${guard_dir}/pyproject.toml" ]; then
    print_error "DevLab Guard source was not found at ${guard_dir}."
    return 1
  fi
  if ! command -v uv >/dev/null 2>&1; then
    print_error "uv is required to run DevLab Guard. Install uv and retry."
    return 1
  fi
  if [ ! -d "$APP_DIR" ]; then
    print_error "${APP_NAME} production directory was not found at ${APP_DIR}."
    return 1
  fi

  print_banner "${APP_NAME} — DevLab Guard"
  print_info "Scanning ${APP_DIR} in read-only mode..."
  uv run --project "$guard_dir" devlab-guard "$APP_DIR"
}
