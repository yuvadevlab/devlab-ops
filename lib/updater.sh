#!/usr/bin/env bash
set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"
source "${SOURCE_DIR}/backup.sh"

update_app() {
  local target_app="$1"
  load_app_config "$target_app"

  print_banner "${APP_NAME} — Safe Update from 'main'"

  # 1. Database backup first
  echo -e "\n${YELLOW}Step 1/4: Safeguarding database with pre-update snapshot...${NC}"
  backup_single_app "$target_app"

  # 2. Pull latest main in APP_DIR
  echo -e "\n${YELLOW}Step 2/4: Pulling latest commits from origin/main...${NC}"
  cd "$APP_DIR"
  local prev_commit=$(git rev-parse --short HEAD)
  git pull origin main
  local new_commit=$(git rev-parse --short HEAD)

  if [ "$prev_commit" = "$new_commit" ]; then
    print_success "Already at latest commit (${new_commit}). No code changes pulled."
  else
    print_success "Updated: ${prev_commit} ➔ ${new_commit}"
  fi

  # 3. Check for dependency or schema migrations
  echo -e "\n${YELLOW}Step 3/4: Analyzing lockfiles and database schemas...${NC}"
  if git diff "$prev_commit" "$new_commit" --name-only 2>/dev/null | grep -q "pnpm-lock.yaml"; then
    print_info "pnpm-lock.yaml changed. Executing pnpm install..."
    pnpm install --frozen-lockfile
  fi

  if git diff "$prev_commit" "$new_commit" --name-only 2>/dev/null | grep -q "prisma"; then
    print_info "Database schema changes detected. Running migrations..."
    eval "$MIGRATE_CMD"
  fi

  # 4. Rebuild production bundles
  echo -e "\n${YELLOW}Step 4/4: Building production artifacts...${NC}"
  eval "$BUILD_CMD"

  echo -e "\n${BOLD}${GREEN}======================================================${NC}"
  echo -e "${BOLD}${GREEN}   ✓ ${APP_NAME} updated to ${new_commit}!            ${NC}"
  echo -e "${BOLD}${GREEN}   Run ./devlab start ${APP_ID} to launch.            ${NC}"
  echo -e "${BOLD}${GREEN}======================================================${NC}"
}
