#!/usr/bin/env bash

# Resolve DevLab Ops root dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVLAB_OPS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source global platform defaults and styling
source "${DEVLAB_OPS_DIR}/config/platform.env"
source "${DEVLAB_OPS_DIR}/lib/colors.sh"

load_app_config() {
  local target_app="$1"
  if [ -z "$target_app" ]; then
    print_error "No application specified."
    echo -e "Available apps: $(list_available_apps)"
    exit 1
  fi

  local config_file="${DEVLAB_OPS_DIR}/config/apps/${target_app}.env"
  if [ ! -f "$config_file" ]; then
    print_error "Unknown application: '${target_app}'."
    echo -e "Available apps: $(list_available_apps)"
    exit 1
  fi

  source "$config_file"
}

list_available_apps() {
  local apps=""
  for f in "${DEVLAB_OPS_DIR}/config/apps/"*.env; do
    if [ -f "$f" ]; then
      local base=$(basename "$f" .env)
      apps="${apps} ${base}"
    fi
  done
  echo "$apps" | sed 's/^ *//'
}
