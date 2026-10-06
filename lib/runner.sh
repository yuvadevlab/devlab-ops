#!/usr/bin/env bash
set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SOURCE_DIR}/config-loader.sh"

check_and_free_port() {
  local port=$1
  local name=$2
  local pid=$(lsof -ti tcp:${port} 2>/dev/null || true)
  if [ -n "$pid" ]; then
    print_warn "Port ${port} (${name}) is occupied by PID ${pid}. Terminating process..."
    kill -9 $pid 2>/dev/null || true
    sleep 1
  fi
}

poll_readiness() {
  local url="$1"
  local name="$2"
  local max_attempts=30
  local attempt=1
  local start_time=$(date +%s)

  while [ $attempt -le $max_attempts ]; do
    if curl -s -f -m 1 "$url" >/dev/null 2>&1; then
      local elapsed=$(( $(date +%s) - start_time ))
      print_success "[${name}] Verified ready (${url}) in ${elapsed}s"
      return 0
    fi
    sleep 0.5
    attempt=$((attempt + 1))
  done

  print_warn "[${name}] Still initializing after 15s. Check logs for details."
  return 1
}

run_app() {
  local target_app="$1"
  load_app_config "$target_app"

  local today=$(date +"${DEFAULT_DATE_FORMAT}")
  local app_log_base="${LOGS_DIR}/${APP_ID}"
  local date_log_dir="${app_log_base}/${today}"
  local api_log_dir="${date_log_dir}/api"
  local web_log_dir="${date_log_dir}/web"

  mkdir -p "$api_log_dir" "$web_log_dir"

  # Master and Sub-stream Files
  local e2e_log="${date_log_dir}/e2e.log"
  local master_err_log="${date_log_dir}/error.log"
  local api_all_log="${api_log_dir}/api.log"
  local api_err_log="${api_log_dir}/error.log"
  local api_http_log="${api_log_dir}/http.log"
  local web_all_log="${web_log_dir}/web.log"
  local web_err_log="${web_log_dir}/error.log"
  local rt_all_log="${date_log_dir}/realtime.log"
  local wrk_all_log="${date_log_dir}/worker.log"

  # Pre-initialize all files immediately
  touch "$e2e_log" "$master_err_log" "$api_all_log" "$api_err_log" "$api_http_log" "$web_all_log" "$web_err_log" "$rt_all_log" "$wrk_all_log"

  # Link latest directory
  ln -sfn "${today}" "${app_log_base}/latest"

  # Auto-prune logs older than RETENTION_DAYS
  find "$app_log_base" -mindepth 1 -maxdepth 1 -type d -name "20*" -mtime +"${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true

  print_banner "${APP_NAME} — Production Runner"
  echo -e "   Web Application : ${GREEN}${WEB_URL}${NC}"
  echo -e "   REST API / Docs : ${CYAN}${DOCS_URL}${NC}"
  if [ -n "$REALTIME_PORT" ]; then
    echo -e "   Realtime Broker : ${YELLOW}http://localhost:${REALTIME_PORT}${NC}"
  fi
  if [ -n "$WORKER_PORT" ]; then
    echo -e "   Background Queue: ${MAGENTA}Port ${WORKER_PORT}${NC}"
  fi
  echo -e "   Database Target : ${YELLOW}${DB_NAME} (Port ${DB_PORT})${NC}"
  echo -e "   Date Partition  : ${BOLD}${today}${NC}"
  echo -e "   Log Directory   : ${DIM}${date_log_dir}${NC}"
  echo -e "${BOLD}${CYAN}------------------------------------------------------${NC}"

  # Port protection
  check_and_free_port "$API_PORT" "${APP_NAME} API"
  check_and_free_port "$WEB_PORT" "${APP_NAME} Web"
  if [ -n "$REALTIME_PORT" ]; then
    check_and_free_port "$REALTIME_PORT" "${APP_NAME} Realtime"
  fi
  if [ -n "$WORKER_PORT" ]; then
    check_and_free_port "$WORKER_PORT" "${APP_NAME} Worker"
  fi

  # Verify builds exist inside APP_DIR
  cd "$APP_DIR"
  if [ -n "$BUILD_CHECK_API" ] && [ ! -f "$BUILD_CHECK_API" ]; then
    print_warn "API build missing (${BUILD_CHECK_API}). Running ${BUILD_CMD}..."
    eval "$BUILD_CMD"
  fi
  if [ -n "$BUILD_CHECK_WEB" ] && [ ! -d "$BUILD_CHECK_WEB" ]; then
    print_warn "Web build missing (${BUILD_CHECK_WEB}). Running ${BUILD_CMD}..."
    eval "$BUILD_CMD"
  fi

  cleanup() {
    echo ""
    print_warn "Shutting down ${APP_NAME} Production..."
    [ -n "$API_PID" ] && kill "$API_PID" 2>/dev/null || true
    [ -n "$WEB_PID" ] && kill "$WEB_PID" 2>/dev/null || true
    [ -n "$REALTIME_PID" ] && kill "$REALTIME_PID" 2>/dev/null || true
    [ -n "$WORKER_PID" ] && kill "$WORKER_PID" 2>/dev/null || true
    [ -n "$API_PID" ] && wait "$API_PID" 2>/dev/null || true
    [ -n "$WEB_PID" ] && wait "$WEB_PID" 2>/dev/null || true
    [ -n "$REALTIME_PID" ] && wait "$REALTIME_PID" 2>/dev/null || true
    [ -n "$WORKER_PID" ] && wait "$WORKER_PID" 2>/dev/null || true
    print_success "${APP_NAME} shutdown complete."
    exit 0
  }

  trap cleanup INT TERM EXIT

  # Start API with Stream Multiplexer
  eval "$API_START_CMD" 2>&1 | awk \
    -v prefix="$(printf "${CYAN}[API:${API_PORT}]${NC} ")" \
    -v e2e_file="$e2e_log" \
    -v master_err="$master_err_log" \
    -v api_file="$api_all_log" \
    -v api_err="$api_err_log" \
    -v http_file="$api_http_log" \
    '
    {
      print prefix $0;
      clean = $0;
      gsub(/\x1b\[[0-9;]*[a-zA-Z]/, "", clean);
      print "[API] " clean >> e2e_file;
      print clean >> api_file;
      if (clean ~ /(ERROR|WARN|Error|Exception|Failed|fatal)/) {
        print clean >> api_err;
        print "[API] " clean >> master_err;
      }
      if (clean ~ /(GET|POST|PUT|PATCH|DELETE|OPTIONS) \/api/) {
        print clean >> http_file;
      }
      fflush();
    }' &
  API_PID=$!

  # Start Realtime if configured
  if [ -n "$REALTIME_START_CMD" ]; then
    eval "$REALTIME_START_CMD" 2>&1 | awk \
      -v prefix="$(printf "${YELLOW}[RT:${REALTIME_PORT}]${NC} ")" \
      -v e2e_file="$e2e_log" \
      -v master_err="$master_err_log" \
      -v rt_file="$rt_all_log" \
      '
      {
        print prefix $0;
        clean = $0;
        gsub(/\x1b\[[0-9;]*[a-zA-Z]/, "", clean);
        print "[RT] " clean >> e2e_file;
        print clean >> rt_file;
        if (clean ~ /(ERROR|WARN|Error|Exception|Failed|fatal)/) {
          print "[RT] " clean >> master_err;
        }
        fflush();
      }' &
    REALTIME_PID=$!
  fi

  # Start Worker if configured
  if [ -n "$WORKER_START_CMD" ]; then
    eval "$WORKER_START_CMD" 2>&1 | awk \
      -v prefix="$(printf "${MAGENTA}[WRK:${WORKER_PORT}]${NC} ")" \
      -v e2e_file="$e2e_log" \
      -v master_err="$master_err_log" \
      -v wrk_file="$wrk_all_log" \
      '
      {
        print prefix $0;
        clean = $0;
        gsub(/\x1b\[[0-9;]*[a-zA-Z]/, "", clean);
        print "[WRK] " clean >> e2e_file;
        print clean >> wrk_file;
        if (clean ~ /(ERROR|WARN|Error|Exception|Failed|fatal)/) {
          print "[WRK] " clean >> master_err;
        }
        fflush();
      }' &
    WORKER_PID=$!
  fi

  # Start Web with Stream Multiplexer
  eval "$WEB_START_CMD" 2>&1 | awk \
    -v prefix="$(printf "${GREEN}[WEB:${WEB_PORT}]${NC} ")" \
    -v e2e_file="$e2e_log" \
    -v master_err="$master_err_log" \
    -v web_file="$web_all_log" \
    -v web_err="$web_err_log" \
    '
    {
      print prefix $0;
      clean = $0;
      gsub(/\x1b\[[0-9;]*[a-zA-Z]/, "", clean);
      print "[WEB] " clean >> e2e_file;
      print clean >> web_file;
      if (clean ~ /(ERROR|WARN|Error|Exception|Failed|fatal)/) {
        print clean >> web_err;
        print "[WEB] " clean >> master_err;
      }
      fflush();
    }' &
  WEB_PID=$!

  # Asynchronous Health Probes
  (
    sleep 1
    poll_readiness "$HEALTH_URL" "${APP_NAME} API" || true
    if [ -n "$REALTIME_URL" ]; then
      poll_readiness "$REALTIME_URL" "${APP_NAME} Realtime" || true
    fi
    poll_readiness "$WEB_URL" "${APP_NAME} Web" || true
  ) &

  print_success "${APP_NAME} launched! (Press Ctrl+C to stop)"
  wait
}

stop_app() {
  local target_app="$1"
  load_app_config "$target_app"

  print_info "Stopping ${APP_NAME}..."
  check_and_free_port "$API_PORT" "${APP_NAME} API"
  check_and_free_port "$WEB_PORT" "${APP_NAME} Web"
  if [ -n "$REALTIME_PORT" ]; then
    check_and_free_port "$REALTIME_PORT" "${APP_NAME} Realtime"
  fi
  if [ -n "$WORKER_PORT" ]; then
    check_and_free_port "$WORKER_PORT" "${APP_NAME} Worker"
  fi
  print_success "${APP_NAME} stopped."
}
