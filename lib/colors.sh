#!/usr/bin/env bash

# Terminal Colors & Styling
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

print_banner() {
  local title="$1"
  echo -e "${BOLD}${CYAN}======================================================${NC}"
  echo -e "${BOLD}${CYAN}   🚀 DevLab Ops — ${title}${NC}"
  echo -e "${BOLD}${CYAN}======================================================${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
  echo -e "${CYAN}ℹ $1${NC}"
}

print_warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}✖ $1${NC}"
}
