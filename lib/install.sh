#!/usr/bin/env bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

install_cli() {
  print_banner "Global CLI & Shell Completion Setup"

  local bin_dir="${HOME}/.local/bin"
  mkdir -p "$bin_dir"

  local devlab_bin="${DEVLAB_OPS_DIR}/devlab"
  local target_link="${bin_dir}/devlab"

  ln -sfn "$devlab_bin" "$target_link"
  print_success "Symlinked CLI to ${target_link}"

  # Verify PATH
  local zshrc="${HOME}/.zshrc"
  if ! echo "$PATH" | grep -q "$bin_dir"; then
    if ! grep -q '.local/bin' "$zshrc" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$zshrc"
      print_info "Added ~/.local/bin to your PATH in ~/.zshrc"
    fi
  fi

  # Generate Zsh Autocompletion
  local completion_dir="${HOME}/.zsh/completion"
  mkdir -p "$completion_dir"
  local comp_file="${completion_dir}/_devlab"

  cat << 'COMP_EOF' > "$comp_file"
#compdef devlab

_devlab() {
  local -a commands
  commands=(
    'start:Start application services with live streaming logs'
    'stop:Stop running services and free ports'
    'update:Backup DB, pull latest main, migrate & rebuild'
    'logs:Inspect logs (e2e, error, api, web, http)'
    'backup:Create timestamped gzipped database snapshots'
    'restore:Interactive database restore from backup'
    'env:Audit environment variables and check for drift'
    'doctor:Run platform diagnostic & port check'
    'stats:Inspect log and backup storage consumption'
    'install:Install global CLI symlink and shell completion'
    'help:Display guidance'
  )

  local -a apps
  apps=(finai orchestrai)

  _arguments -C \
    '1: :->command' \
    '2: :->app' \
    '3: :->option'

  case "$state" in
    command)
      _describe -t commands 'devlab command' commands
      ;;
    app)
      case "$words[2]" in
        start|stop|update|logs|backup|restore|env)
          _describe -t apps 'application' apps
          ;;
      esac
      ;;
    option)
      case "$words[2]" in
        logs)
          local -a streams
          streams=(e2e error api web http list)
          _describe -t streams 'log stream' streams
          ;;
      esac
      ;;
  esac
}

_devlab "$@"
COMP_EOF

  # Ensure fpath includes completion directory in .zshrc
  if ! grep -q 'fpath=(~/.zsh/completion' "$zshrc" 2>/dev/null; then
    echo -e '\nfpath=(~/.zsh/completion $fpath)\nautoload -Uz compinit && compinit -u' >> "$zshrc"
    print_info "Configured Zsh autocompletion in ~/.zshrc"
  fi

  print_success "Global CLI installation complete!"
  echo -e "\n${BOLD}Next steps:${NC}"
  echo -e "1. Run: ${CYAN}source ~/.zshrc${NC}"
  echo -e "2. You can now run ${BOLD}devlab <command>${NC} from ANY terminal tab with Tab completion!"
}
