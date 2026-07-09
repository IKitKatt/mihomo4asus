start_mihomo() {
    ensure_dirs
    ensure_alias
    is_running && die "mihomo is already running"
    rm -f "$MIHOMO_HOME/mihomo-debug.log" "$RUN_DIR/mihomo-supervisor.pid" "$RUN_DIR/stop.flag" 2>/dev/null
    clear_core_log
    : > "$LOG_FILE" 2>/dev/null || die "cannot create $LOG_FILE"
    subscription_update_if_needed
    cfg="$(config_file)" || die "missing active config"
    [ -x "$MIHOMO_BIN" ] || die "missing executable $MIHOMO_BIN"

    detect_tproxy_port "$cfg" >/dev/null || die "config $cfg must contain numeric tproxy-port, for example: tproxy-port: 7894"
    load_kernel_modules

    log "starting mihomo with $cfg"
    "$MIHOMO_BIN" -d "$MIHOMO_HOME" -f "$cfg" >> "$LOG_FILE" 2>&1 &
    echo "$!" > "$PID_FILE"
    start_log_guard
    sleep 3
    if ! is_running; then
        stop_log_guard
        echo "Last Mihomo log lines:" >&2
        tail -n 30 "$LOG_FILE" >&2
        die "mihomo failed to start; check $LOG_FILE"
    fi

    case "$(proxy_mode)" in
        tproxy)
            apply_rules
            ;;
        mixed|tun)
            flush_rules
            echo "$(proxy_mode)" > "$MODE_FILE"
            log "mihomo core started without TProxy routing rules: mode=$(proxy_mode)"
            ;;
    esac
    install_hooks
    start_subscription_updater
    log "mihomo started in $(proxy_mode) mode"
}

reload_mihomo_config() {
    ensure_dirs
    is_running || die "mihomo is not running"
    cfg="$(config_file)" || die "missing active config"
    controller="$(detect_controller_addr "$cfg" 2>/dev/null)"
    [ -n "$controller" ] || die "config must contain external-controller for config reload"
    case "$controller" in
        unix://*|https://*) die "only http external-controller reload is supported for now" ;;
    esac
    controller_host="${controller%:*}"
    controller_port="${controller##*:}"
    [ "$controller_host" = "0.0.0.0" ] && controller_host="127.0.0.1"
    [ "$controller_host" = "::" ] && controller_host="127.0.0.1"
    case "$controller_port" in ''|*[!0-9]*) die "cannot detect external-controller port from $controller" ;; esac

    curl_bin="$(find_command_path curl 2>/dev/null)"
    [ -n "$curl_bin" ] || die "curl is required to reload Mihomo config"
    secret="$(detect_controller_secret "$cfg" 2>/dev/null)"
    tmp_body="$RUN_DIR/reload-config.json"
    printf '{"path":"%s","force":true}\n' "$cfg" > "$tmp_body" || die "cannot write $tmp_body"
    if [ -n "$secret" ]; then
        "$curl_bin" -fsS -X PUT "http://$controller_host:$controller_port/configs" \
            -H "Authorization: Bearer $secret" \
            -H "Content-Type: application/json" \
            --data-binary "@$tmp_body" >/dev/null || die "Mihomo controller config reload failed"
    else
        "$curl_bin" -fsS -X PUT "http://$controller_host:$controller_port/configs" \
            -H "Content-Type: application/json" \
            --data-binary "@$tmp_body" >/dev/null || die "Mihomo controller config reload failed"
    fi
    apply_rules
    log "mihomo config reloaded through controller"
}

stop_mihomo() {
    flush_rules
    stop_log_guard
    stop_subscription_updater

    if ! is_running; then
        rm -f "$PID_FILE" "$MODE_FILE"
        clear_core_log
        log "mihomo stopped"
        return 0
    fi

    mihomo_pids | sort -u | while read pid; do
        kill "$pid" 2>/dev/null
    done
    if ! wait_stopped 10; then
        mihomo_pids | sort -u | while read pid; do
            kill -9 "$pid" 2>/dev/null
        done
        wait_stopped 3 || die "cannot stop mihomo process"
    fi

    rm -f "$PID_FILE" "$MODE_FILE"
    clear_core_log
    log "mihomo stopped"
}
