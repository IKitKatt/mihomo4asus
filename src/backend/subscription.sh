start_subscription_updater() {
    stop_subscription_updater
    [ "$(subscription_type)" = "url" ] || return 0
    subscription_url="$(subscription_setting url)"
    [ -n "$subscription_url" ] || return 0
    subscription_hours="$(subscription_update_hours)"
    subscription_seconds=$((subscription_hours * 3600))

    (
        sleep "$subscription_seconds"
        while :; do
            MIHOMO_SCRIPT_DEPTH=0 "$SCRIPT_PATH" subscription update-auto >/dev/null 2>&1
            sleep "$subscription_seconds"
        done
    ) &
    echo "$!" > "$SUBSCRIPTION_PID_FILE"
}

stop_subscription_updater() {
    updater_pid="$(cat "$SUBSCRIPTION_PID_FILE" 2>/dev/null)"
    case "$updater_pid" in
        ''|*[!0-9]*) ;;
        *) kill "$updater_pid" 2>/dev/null ;;
    esac
    rm -f "$SUBSCRIPTION_PID_FILE"
}

log_subscription_network_info() {
    url="$1"
    host="$(url_host "$url")"
    [ -n "$host" ] || return 0

    log "subscription host: $host"
    ns_line="$(host_resolved_ips "$host" | awk 'BEGIN { out="" } { out = out ? out "," $1 : $1 } END { print out }')"
    [ -n "$ns_line" ] && log "subscription host resolved to: $ns_line"

    if command -v ping >/dev/null 2>&1; then
        ping -c 1 -W 2 "$host" >/dev/null 2>&1 && log "subscription host ping: ok" || log "subscription host ping: failed"
    fi
}

subscription_response_valid() {
    file="$1"
    [ -s "$file" ] || return 1
    if awk '
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*</ { bad=1 }
        { exit }
        END { exit bad ? 0 : 1 }
    ' "$file"; then
        return 1
    fi
    awk '
        /^[[:space:]]*(proxies|proxy-groups|rules|proxy-providers|rule-providers|dns|mixed-port|port|socks-port|redir-port|tproxy-port):[[:space:]]*/ {
            found=1
            exit
        }
        END { exit found ? 0 : 1 }
    ' "$file"
}

host_resolved_ips() {
    host="$1"
    if command -v nslookup >/dev/null 2>&1; then
        nslookup "$host" 2>/dev/null
    elif [ -x /bin/busybox ]; then
        /bin/busybox nslookup "$host" 2>/dev/null
    else
        return 1
    fi | awk '
        /^Name:/ { in_answer=1; next }
        /^Non-authoritative answer:/ { in_answer=1; next }
        in_answer && /^Address[ 0-9]*:/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) print $i
            }
        }
        in_answer && /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print $1 }
    ' | awk '!seen[$0]++'
}

known_lan_targets() {
    port="$1"

    {
        printf '127.0.0.1\n'
        if [ -f /var/lib/misc/dnsmasq.leases ]; then
            awk '{ print $3 }' /var/lib/misc/dnsmasq.leases 2>/dev/null
        fi
        if command -v nvram >/dev/null 2>&1; then
            nvram get dhcp_staticlist 2>/dev/null | tr '<' '\n' | awk -F'>' 'NF >= 2 { print $2 }'
        fi
        if command -v ip >/dev/null 2>&1; then
            ip neigh show dev "$LAN_IF" 2>/dev/null | awk '$1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ && $NF !~ /FAILED|INCOMPLETE/ { print $1 }'
        fi
    } | awk -v port="$port" '
        /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ && !seen[$0]++ { print $0 ":" port }
    '
}

detect_device_model() {
    model=""
    if command -v nvram >/dev/null 2>&1; then
        model="$(nvram get odmpid 2>/dev/null)"
        [ -n "$model" ] || model="$(nvram get productid 2>/dev/null)"
        [ -n "$model" ] || model="$(nvram get model 2>/dev/null)"
    fi
    [ -n "$model" ] || model="$(get_uname -n 2>/dev/null)"
    [ -n "$model" ] || model="unknown"
    printf '%s\n' "$model"
}

detect_firmware_version() {
    firmver=""
    buildno=""
    extendno=""
    if command -v nvram >/dev/null 2>&1; then
        firmver="$(nvram get firmver 2>/dev/null)"
        buildno="$(nvram get buildno 2>/dev/null)"
        extendno="$(nvram get extendno 2>/dev/null)"
    fi

    if [ -n "$firmver" ] && [ -n "$extendno" ]; then
        case "$extendno" in
            "$firmver"*) printf '%s\n' "$extendno"; return 0 ;;
            *) printf '%s.%s\n' "$firmver" "$extendno"; return 0 ;;
        esac
    fi
    if [ -n "$firmver" ] && [ -n "$buildno" ]; then
        case "$firmver" in
            *"$buildno"*) printf '%s\n' "$firmver"; return 0 ;;
            *) printf '%s.%s\n' "$firmver" "$buildno"; return 0 ;;
        esac
    fi
    [ -n "$firmver" ] && { printf '%s\n' "$firmver"; return 0; }
    get_uname -r
}

hwid_date() {
    if [ -f "$SUBSCRIPTION_HWID_DATE_FILE" ]; then
        date_value="$(cat "$SUBSCRIPTION_HWID_DATE_FILE" 2>/dev/null)"
    else
        date_value="$(date +%Y%m%d 2>/dev/null || date 2>/dev/null || printf 'unknown')"
        printf '%s\n' "$date_value" > "$SUBSCRIPTION_HWID_DATE_FILE" 2>/dev/null
    fi
    [ -n "$date_value" ] || date_value="unknown"
    printf '%s\n' "$date_value"
}

hash_hwid_source() {
    source_text="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$source_text" | sha256sum | awk '{print $1}'
    elif [ -x /opt/bin/sha256sum ]; then
        printf '%s' "$source_text" | /opt/bin/sha256sum | awk '{print $1}'
    elif command -v busybox >/dev/null 2>&1 && busybox sha256sum /dev/null >/dev/null 2>&1; then
        printf '%s' "$source_text" | busybox sha256sum | awk '{print $1}'
    elif [ -x /bin/busybox ] && /bin/busybox sha256sum /dev/null >/dev/null 2>&1; then
        printf '%s' "$source_text" | /bin/busybox sha256sum | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s' "$source_text" | openssl dgst -sha256 2>/dev/null | awk '{print $NF}'
    elif [ -x /opt/bin/openssl ]; then
        printf '%s' "$source_text" | /opt/bin/openssl dgst -sha256 2>/dev/null | awk '{print $NF}'
    elif command -v md5sum >/dev/null 2>&1; then
        printf '%s' "$source_text" | md5sum | awk '{print $1}'
    elif [ -x /opt/bin/md5sum ]; then
        printf '%s' "$source_text" | /opt/bin/md5sum | awk '{print $1}'
    elif command -v busybox >/dev/null 2>&1 && busybox md5sum /dev/null >/dev/null 2>&1; then
        printf '%s' "$source_text" | busybox md5sum | awk '{print $1}'
    elif [ -x /bin/busybox ] && /bin/busybox md5sum /dev/null >/dev/null 2>&1; then
        printf '%s' "$source_text" | /bin/busybox md5sum | awk '{print $1}'
    else
        printf '%s' "$source_text" | sed 's/[^A-Za-z0-9]//g;s/^\(.\{1,64\}\).*/\1/'
    fi
}

valid_hwid() {
    value="$1"
    printf '%s' "$value" | awk '
        /^[A-Za-z0-9=-]{10,64}$/ { ok=1 }
        END { exit ok ? 0 : 1 }
    '
}

generated_hwid() {
    ver_os="$(detect_firmware_version)"
    device_model="$(detect_device_model)"
    date_value="$(hwid_date)"
    hwid="$(hash_hwid_source "$ver_os$device_model$date_value")"
    hwid="$(printf '%s' "$hwid" | sed 's/[^A-Za-z0-9=-]//g;s/^\(.\{1,32\}\).*/\1/')"
    if valid_hwid "$hwid"; then
        printf '%s\n' "$hwid"
    else
        printf '%s\n' "mihomo4asus$(date +%s 2>/dev/null | sed 's/[^0-9]//g;s/^\(.\{1,20\}\).*/\1/')"
    fi
}

subscription_hwid() {
    hwid="${SUBSCRIPTION_HWID:-$(subscription_setting hwid)}"
    if [ -n "$hwid" ]; then
        valid_hwid "$hwid" || die "subscription HWID must match ^[A-Za-z0-9=-]{10,64}$"
        printf '%s\n' "$hwid"
        return 0
    fi
    generated_hwid
}

subscription_user_agent() {
    user_agent="${SUBSCRIPTION_USER_AGENT:-$(subscription_setting user_agent)}"
    [ -n "$user_agent" ] || user_agent="mihomo4asus/$SCRIPT_VERSION"
    printf '%s\n' "$user_agent"
}

subscription_scan_local() {
    value="${SUBSCRIPTION_SCAN_LOCAL:-$(subscription_setting scan_local)}"
    case "$value" in
        1|yes|on|true|enabled) printf '%s\n' "1" ;;
        *) printf '%s\n' "0" ;;
    esac
}

subscription_hwid_enabled() {
    value="${SUBSCRIPTION_HWID_ENABLED:-$(subscription_setting hwid_enabled)}"
    case "$value" in
        0|no|off|false|disabled) printf '%s\n' "0" ;;
        *) printf '%s\n' "1" ;;
    esac
}

subscription_headers() {
    device_os="Linux"
    ver_os="$(detect_firmware_version)"
    device_model="$(detect_device_model)"
    if [ "$(subscription_hwid_enabled)" = "1" ]; then
        hwid="$(subscription_hwid)"
    else
        hwid=""
    fi
    user_agent="$(subscription_user_agent)"

    printf '%s\n' "$hwid"
    printf '%s\n' "$device_os"
    printf '%s\n' "$ver_os"
    printf '%s\n' "$device_model"
    printf '%s\n' "$user_agent"
}

yaml_flow_value() {
    printf '%s' "$1" | tr '\r\n' '  ' | sed 's/\\/\\\\/g;s/"/\\"/g'
}

prepare_proxy_provider_runtime_config() {
    source_config="$1"
    [ -f "$source_config" ] || return 1
    [ "$(subscription_hwid_enabled)" = "1" ] || {
        rm -f "$RUNTIME_CONFIG_FILE" 2>/dev/null
        printf '%s\n' "$source_config"
        return 0
    }
    grep -q '^[[:space:]]*proxy-providers:[[:space:]]*' "$source_config" 2>/dev/null || {
        rm -f "$RUNTIME_CONFIG_FILE" 2>/dev/null
        printf '%s\n' "$source_config"
        return 0
    }

    headers="$(subscription_headers)"
    hwid="$(printf '%s\n' "$headers" | sed -n '1p' | yaml_flow_value)"
    device_os="$(printf '%s\n' "$headers" | sed -n '2p' | yaml_flow_value)"
    ver_os="$(printf '%s\n' "$headers" | sed -n '3p' | yaml_flow_value)"
    device_model="$(printf '%s\n' "$headers" | sed -n '4p' | yaml_flow_value)"
    user_agent="$(printf '%s\n' "$headers" | sed -n '5p' | yaml_flow_value)"
    tmp_config="$RUN_DIR/mihomo-runtime.yaml.$$"

    awk -v user_agent="$user_agent" -v hwid="$hwid" -v device_os="$device_os" -v ver_os="$ver_os" -v device_model="$device_model" '
        /^[[:space:]]*proxy-providers:[[:space:]]*($|#)/ { in_providers=1 }
        in_providers && /^[^[:space:]#][^:]*:[[:space:]]*/ && $0 !~ /^[[:space:]]*proxy-providers:/ { in_providers=0 }
        {
            line=$0
            indent=line
            sub(/[^[:space:]].*$/, "", indent)
            if (in_providers && line ~ /^[[:space:]]*User-Agent:[[:space:]]*\[[[:space:]]*\][[:space:]]*(#.*)?$/) {
                print indent "User-Agent: [\"" user_agent "\"]"
                next
            }
            if (in_providers && line ~ /^[[:space:]]*x-hwid:[[:space:]]*\[[[:space:]]*\][[:space:]]*(#.*)?$/) {
                print indent "x-hwid: [\"" hwid "\"]"
                next
            }
            if (in_providers && line ~ /^[[:space:]]*x-device-os:[[:space:]]*\[[[:space:]]*\][[:space:]]*(#.*)?$/) {
                print indent "x-device-os: [\"" device_os "\"]"
                next
            }
            if (in_providers && line ~ /^[[:space:]]*x-ver-os:[[:space:]]*\[[[:space:]]*\][[:space:]]*(#.*)?$/) {
                print indent "x-ver-os: [\"" ver_os "\"]"
                next
            }
            if (in_providers && line ~ /^[[:space:]]*x-device-model:[[:space:]]*\[[[:space:]]*\][[:space:]]*(#.*)?$/) {
                print indent "x-device-model: [\"" device_model "\"]"
                next
            }
            print line
        }
    ' "$source_config" > "$tmp_config" || {
        rm -f "$tmp_config"
        return 1
    }

    if cmp -s "$source_config" "$tmp_config" 2>/dev/null; then
        rm -f "$tmp_config" "$RUNTIME_CONFIG_FILE"
        printf '%s\n' "$source_config"
        return 0
    fi
    mv "$tmp_config" "$RUNTIME_CONFIG_FILE" || return 1
    printf '%s\n' "$RUNTIME_CONFIG_FILE"
}

curl_subscription_to_file() {
    curl_bin="$1"
    hdr_file="$2"
    err_file="$3"
    dst="$4"
    url="$5"
    connect_to="$6"
    timeout_connect="$7"
    timeout_total="$8"
    user_agent="$9"
    accept_header="${10}"
    hwid="${11}"
    device_os="${12}"
    ver_os="${13}"
    device_model="${14}"

    connect_args=""
    [ -n "$connect_to" ] && connect_args="--connect-to $connect_to"

    if [ -n "$hwid" ]; then
        # shellcheck disable=SC2086
        "$curl_bin" -4 --http1.1 -fsSL --compressed --retry 1 --retry-delay 1 \
            --connect-timeout "$timeout_connect" -m "$timeout_total" \
            -D "$hdr_file" $connect_args -A "$user_agent" -H "$accept_header" \
            -H "x-hwid: $hwid" -H "x-device-os: $device_os" -H "x-ver-os: $ver_os" -H "x-device-model: $device_model" \
            -o "$dst" "$url" 2>"$err_file"
    else
        # shellcheck disable=SC2086
        "$curl_bin" -4 --http1.1 -fsSL --compressed --retry 1 --retry-delay 1 \
            --connect-timeout "$timeout_connect" -m "$timeout_total" \
            -D "$hdr_file" $connect_args -A "$user_agent" -H "$accept_header" \
            -H "x-device-os: $device_os" -H "x-ver-os: $ver_os" -H "x-device-model: $device_model" \
            -o "$dst" "$url" 2>"$err_file"
    fi
}

http_get_subscription_to_file() {
    url="$1"
    dst="$2"
    err_file="$RUN_DIR/subscription-http.err.$$"
    hdr_file="$RUN_DIR/subscription-http.headers.$$"
    host="$(url_host "$url")"
    port="$(url_port "$url")"
    headers="$(subscription_headers)"
    hwid="$(printf '%s\n' "$headers" | sed -n '1p')"
    device_os="$(printf '%s\n' "$headers" | sed -n '2p')"
    ver_os="$(printf '%s\n' "$headers" | sed -n '3p')"
    device_model="$(printf '%s\n' "$headers" | sed -n '4p')"
    user_agent="$(printf '%s\n' "$headers" | sed -n '5p')"
    accept_header="Accept: application/json, text/plain, */*"

    rm -f "$dst" "$err_file" "$hdr_file"
    log_subscription_network_info "$(mask_url_for_log "$url")"

    curl_bin="$(find_command_path curl 2>/dev/null)"
    [ -n "$curl_bin" ] || {
        log "curl is required to request subscription config"
        return 1
    }

    if curl_subscription_to_file "$curl_bin" "$hdr_file" "$err_file" "$dst" "$url" "" "$SUBSCRIPTION_CONNECT_TIMEOUT" "$SUBSCRIPTION_MAX_TIME" "$user_agent" "$accept_header" "$hwid" "$device_os" "$ver_os" "$device_model" && subscription_response_valid "$dst"; then
        rm -f "$err_file" "$hdr_file"
        return 0
    fi
    log_http_error "curl direct subscription request failed" "$err_file"
    rm -f "$dst" "$err_file" "$hdr_file"

    if [ "$(subscription_scan_local)" != "1" ]; then
        log "subscription local address recovery is disabled; enable it with: mihomo subscription scan-local on"
        rm -f "$err_file" "$hdr_file"
        return 1
    fi

    scan_targets="$(known_lan_targets "$port")"
    if [ -n "$scan_targets" ]; then
        log "subscription local recovery: checking known LAN addresses on port $port"
        scanned=0
        while read scan_target; do
            [ -n "$scan_target" ] || continue
            scanned=$((scanned + 1))
            [ "$scanned" -le "$SUBSCRIPTION_SCAN_LIMIT" ] 2>/dev/null || {
                log "subscription local recovery stopped after $SUBSCRIPTION_SCAN_LIMIT candidates"
                break
            }
            scan_ip="${scan_target%:*}"
            scan_port="${scan_target##*:}"
            if curl_subscription_to_file "$curl_bin" "$hdr_file" "$err_file" "$dst" "$url" "$host:$port:$scan_ip:$scan_port" 1 4 "$user_agent" "$accept_header" "$hwid" "$device_os" "$ver_os" "$device_model" && subscription_response_valid "$dst"; then
                log "subscription recovered from local address: $scan_target"
                rm -f "$err_file" "$hdr_file"
                return 0
            fi
            rm -f "$dst" "$err_file" "$hdr_file"
        done <<EOF
$scan_targets
EOF
    fi

    log "subscription request failed after local recovery: $(mask_url_for_log "$url")"
    rm -f "$err_file" "$hdr_file"
    return 1
}

subscription_setting() {
    name="$1"
    [ -f "$SUBSCRIPTION_SETTINGS_FILE" ] || return 0
    case "$name" in
        url) key="URL" ;;
        hours) key="UPDATE_HOURS" ;;
        type) key="TYPE" ;;
        hwid) key="HWID" ;;
        hwid_enabled) key="HWID_ENABLED" ;;
        user_agent) key="USER_AGENT" ;;
        scan_local) key="SCAN_LOCAL" ;;
        *) return 1 ;;
    esac
    grep -m1 "^$key=" "$SUBSCRIPTION_SETTINGS_FILE" 2>/dev/null | sed 's/^[^=]*=//;s/\r$//'
}

subscription_type() {
    type="$(subscription_setting type)"
    case "$type" in
        url|remote) printf '%s\n' "url" ;;
        local) printf '%s\n' "local" ;;
        *)
            if [ -n "$(subscription_setting url)" ]; then
                printf '%s\n' "url"
            else
                printf '%s\n' "local"
            fi
            ;;
    esac
}

subscription_update_hours() {
    hours="$(subscription_setting hours)"
    case "$hours" in
        ''|*[!0-9]*) hours=1 ;;
    esac
    [ "$hours" -gt 0 ] 2>/dev/null || hours=1
    printf '%s\n' "$hours"
}

write_subscription_settings_file() {
    tmp_settings="$1"
    type="$2"
    url="$3"
    hours="$4"
    hwid="$5"
    user_agent="$6"
    scan_local="$7"
    hwid_enabled="$8"
    rm -f "$tmp_settings" 2>/dev/null
    {
        printf 'TYPE=%s\n' "$type"
        printf 'URL=%s\n' "$url"
        printf 'UPDATE_HOURS=%s\n' "$hours"
        printf 'HWID=%s\n' "$hwid"
        printf 'HWID_ENABLED=%s\n' "$hwid_enabled"
        printf 'USER_AGENT=%s\n' "$user_agent"
        printf 'SCAN_LOCAL=%s\n' "$scan_local"
    } > "$tmp_settings"
    return 0
}

save_subscription_settings() {
    type="$1"
    url="$2"
    hours="$3"
    hwid="${4:-$(subscription_setting hwid)}"
    user_agent="${5:-$(subscription_setting user_agent)}"
    scan_local="${6:-$(subscription_setting scan_local)}"
    hwid_enabled="${7:-$(subscription_setting hwid_enabled)}"
    tmp_settings=""
    case "$type" in
        local|url) ;;
        *) die "subscription type must be local or url" ;;
    esac
    if [ "$type" = "url" ] && [ -z "$url" ]; then
        die "subscription URL is required"
    fi
    case "$hours" in
        ''|*[!0-9]*) die "subscription update interval must be a positive number of hours" ;;
    esac
    [ "$hours" -gt 0 ] 2>/dev/null || die "subscription update interval must be greater than zero"
    [ -z "$hwid" ] || valid_hwid "$hwid" || die "subscription HWID must match ^[A-Za-z0-9=-]{10,64}$"
    case "$scan_local" in
        1|yes|on|true|enabled) scan_local=1 ;;
        *) scan_local=0 ;;
    esac
    case "$hwid_enabled" in
        0|no|off|false|disabled) hwid_enabled=0 ;;
        *) hwid_enabled=1 ;;
    esac
    mkdir -p "$STATE_DIR" "$RUN_DIR" 2>/dev/null || die "cannot create subscription settings directories"
    chmod u+rwx "$STATE_DIR" "$RUN_DIR" 2>/dev/null

    for settings_dir in "$STATE_DIR" "$RUN_DIR" /tmp; do
        [ -d "$settings_dir" ] || continue
        tmp_settings="$settings_dir/subscription.conf.$$"
        if write_subscription_settings_file "$tmp_settings" "$type" "$url" "$hours" "$hwid" "$user_agent" "$scan_local" "$hwid_enabled" 2>/dev/null; then
            break
        fi
        rm -f "$tmp_settings" 2>/dev/null
        tmp_settings=""
    done

    [ -n "$tmp_settings" ] && [ -s "$tmp_settings" ] || die "cannot write temporary subscription settings"
    chmod 600 "$tmp_settings" 2>/dev/null
    chmod u+w "$SUBSCRIPTION_SETTINGS_FILE" 2>/dev/null
    rm -f "$SUBSCRIPTION_SETTINGS_FILE" 2>/dev/null
    if ! mv "$tmp_settings" "$SUBSCRIPTION_SETTINGS_FILE" 2>/dev/null; then
        if cp "$tmp_settings" "$SUBSCRIPTION_SETTINGS_FILE" 2>/dev/null; then
            rm -f "$tmp_settings"
            chmod 600 "$SUBSCRIPTION_SETTINGS_FILE" 2>/dev/null
            return 0
        fi
        rm -f "$tmp_settings"
        die "cannot write $SUBSCRIPTION_SETTINGS_FILE"
    fi
    chmod 600 "$SUBSCRIPTION_SETTINGS_FILE" 2>/dev/null
}

subscription_is_due() {
    hours="$(subscription_update_hours)"
    seconds=$((hours * 3600))
    now="$(date +%s 2>/dev/null)"
    case "$now" in
        ''|*[!0-9]*) return 0 ;;
    esac
    last="$(cat "$SUBSCRIPTION_LAST_FILE" 2>/dev/null)"
    case "$last" in
        ''|*[!0-9]*) return 0 ;;
    esac
    age=$((now - last))
    [ "$age" -ge "$seconds" ]
}

touch_subscription_last() {
    now="$(date +%s 2>/dev/null)"
    case "$now" in
        ''|*[!0-9]*) now=0 ;;
    esac
    printf '%s\n' "$now" > "$SUBSCRIPTION_LAST_FILE" 2>/dev/null
}

subscription_update_config() {
    [ "$(subscription_type)" = "url" ] || return 2
    subscription_url="$(subscription_setting url)"
    [ -n "$subscription_url" ] || return 2

    tmp_raw="$RUN_DIR/subscription.raw.$$"

    rm -f "$tmp_raw"
    log "requesting subscription config"
    if ! http_get_subscription_to_file "$subscription_url" "$tmp_raw"; then
        rm -f "$tmp_raw"
        log "ERROR: subscription download failed"
        return 3
    fi
    [ -s "$tmp_raw" ] || {
        rm -f "$tmp_raw"
        log "ERROR: subscription response is empty"
        return 3
    }

    # The temporary file is the decoded HTTP response body. Do not parse,
    # normalize, merge, or otherwise modify it before making it active.
    if [ -f "$SUB_CONFIG_FILE" ] && cmp -s "$SUB_CONFIG_FILE" "$tmp_raw" 2>/dev/null; then
        rm -f "$tmp_raw"
        touch_subscription_last
        log "subscription config unchanged"
        return 1
    fi

    [ -f "$SUB_CONFIG_FILE" ] && cp "$SUB_CONFIG_FILE" "$SUB_CONFIG_FILE.bak" 2>/dev/null
    mv "$tmp_raw" "$SUB_CONFIG_FILE" || {
        rm -f "$tmp_raw"
        log "ERROR: cannot install subscription config"
        return 3
    }
    touch_subscription_last
    log "subscription config updated"
    return 0
}

subscription_update_if_needed() {
    [ "$(subscription_type)" = "url" ] || return 0
    [ -n "$(subscription_setting url)" ] || return 0
    [ -s "$SUB_CONFIG_FILE" ] || { subscription_update_config; return 0; }

    # Starting the core must not wait for a scheduled remote update. The
    # background updater handles the next due refresh after the core is up.
    subscription_is_due && log "subscription update is due; keeping current config until scheduled refresh"
    return 0
}

subscription_update_and_reload() {
    auto="$1"
    ensure_dirs
    [ "$(subscription_type)" = "url" ] || {
        [ "$auto" = "auto" ] && return 0
        die "subscription config type is local"
    }
    [ -n "$(subscription_setting url)" ] || {
        [ "$auto" = "auto" ] && return 0
        die "subscription URL is not configured"
    }

    if [ "$auto" = "auto" ] && ! subscription_is_due; then
        return 0
    fi

    subscription_update_config
    result="$?"
    case "$result" in
        0) ;;
        1)
            if is_running; then
                log "subscription config unchanged; reapplying rules"
                apply_rules
                start_subscription_updater
            fi
            return 0
            ;;
        *)
            [ "$auto" = "auto" ] && return 0
            die "subscription update failed"
            ;;
    esac

    if is_running; then
        log "restarting mihomo after subscription update"
        stop_mihomo
        sleep 2
        start_mihomo
    fi
}
