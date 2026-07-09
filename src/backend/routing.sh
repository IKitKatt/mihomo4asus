load_kernel_modules() {
    lsmod | grep -q "^xt_TPROXY " || modprobe xt_TPROXY 2>/dev/null
}

flush_rules() {
    ip rule del fwmark "$FW_MARK" lookup "$ROUTE_TABLE" priority "$RULE_PRIORITY" 2>/dev/null
    ip rule del fwmark "$FW_MARK" lookup "$ROUTE_TABLE" 2>/dev/null
    ip route flush table "$ROUTE_TABLE" 2>/dev/null

    iptables -t mangle -D PREROUTING -j "$MANGLE_CHAIN" 2>/dev/null
    iptables -t mangle -F "$MANGLE_CHAIN" 2>/dev/null
    iptables -t mangle -X "$MANGLE_CHAIN" 2>/dev/null

    iptables -t nat -D PREROUTING -j "$NAT_CHAIN" 2>/dev/null
    iptables -t nat -F "$NAT_CHAIN" 2>/dev/null
    iptables -t nat -X "$NAT_CHAIN" 2>/dev/null
}

get_wan_ips() {
    if command -v nvram >/dev/null 2>&1; then
        nvram show 2>/dev/null | awk -F= '
            /^(wan|wan[0-9]+)_ipaddr=/ ||
            /^(wan|wan[0-9]+)_realip_ip=/ ||
            /^(wan|wan[0-9]+)_xipaddr=/ ||
            /^ddns_ipaddr=/ ||
            /^external_ip=/ {
                if ($2 ~ /^[1-9][0-9]*\.[0-9]+\.[0-9]+\.[0-9]+$/ && $2 != "0.0.0.0") print $2
            }
        '
    fi
    ip addr show 2>/dev/null | awk '
        /inet / {
            ip=$2
            sub(/\/.*/, "", ip)
            if (ip !~ /^(0|10|127|169\.254|172\.(1[6-9]|2[0-9]|3[0-1])|192\.168)\./) print ip
        }
    '
}

add_wan_bypass_rules() {
    chain="$1"
    for ip in $(get_wan_ips); do
        case "$ip" in
            ''|0.0.0.0) continue ;;
        esac
        iptables -t mangle -A "$chain" -d "$ip" -j RETURN
    done
}

add_bypass_rules() {
    chain="$1"
    iptables -t mangle -A "$chain" -d 0.0.0.0/8 -j RETURN
    iptables -t mangle -A "$chain" -d 10.0.0.0/8 -j RETURN
    iptables -t mangle -A "$chain" -d 100.64.0.0/10 -j RETURN
    iptables -t mangle -A "$chain" -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A "$chain" -d 169.254.0.0/16 -j RETURN
    iptables -t mangle -A "$chain" -d 172.16.0.0/12 -j RETURN
    iptables -t mangle -A "$chain" -d 192.168.0.0/16 -j RETURN
    iptables -t mangle -A "$chain" -d 224.0.0.0/4 -j RETURN
    iptables -t mangle -A "$chain" -d 240.0.0.0/4 -j RETURN
    iptables -t mangle -A "$chain" -d 255.255.255.255/32 -j RETURN
    add_wan_bypass_rules "$chain"
}

routing_mode() {
    mode="$(cat "$ROUTING_MODE_FILE" 2>/dev/null | sed 's/\r$//')"
    case "$mode" in
        include|exclude) printf '%s\n' "$mode" ;;
        *) printf '%s\n' "off" ;;
    esac
}

proxy_mode() {
    mode="$(cat "$PROXY_MODE_FILE" 2>/dev/null | sed 's/\r$//')"
    case "$mode" in
        tproxy|mixed|tun) printf '%s\n' "$mode" ;;
        *) printf '%s\n' "tproxy" ;;
    esac
}

set_proxy_mode() {
    mode="$1"
    case "$mode" in
        tproxy|mixed|tun) ;;
        *) die "proxy mode must be tproxy, mixed or tun" ;;
    esac
    mkdir -p "$STATE_DIR" 2>/dev/null || die "cannot create $STATE_DIR"
    printf '%s\n' "$mode" > "$PROXY_MODE_FILE" || die "cannot write $PROXY_MODE_FILE"
}

set_routing_mode() {
    mode="$1"
    case "$mode" in
        include|exclude|off) ;;
        *) die "routing mode must be include, exclude or off" ;;
    esac
    mkdir -p "$CONFIG_DIR" 2>/dev/null || die "cannot create $CONFIG_DIR"
    printf '%s\n' "$mode" > "$ROUTING_MODE_FILE" || die "cannot write $ROUTING_MODE_FILE"
}

migrate_routing_list() {
    [ -f "$ROUTING_FILE" ] && return 0
    mkdir -p "$STATE_DIR" 2>/dev/null || return 1
    if [ -n "$(list_items "$INCLUDE_FILE")" ]; then
        list_items "$INCLUDE_FILE" > "$ROUTING_FILE"
        set_routing_mode include
    elif [ -n "$(list_items "$EXCLUDE_FILE")" ]; then
        list_items "$EXCLUDE_FILE" > "$ROUTING_FILE"
        set_routing_mode exclude
    else
        : > "$ROUTING_FILE"
        set_routing_mode off
    fi
}

add_exclude_rules() {
    chain="$1"
    [ "$(routing_mode)" = "exclude" ] || return 0
    list_items "$ROUTING_FILE" | while IFS= read -r item || [ -n "$item" ]; do
        iptables -t mangle -A "$chain" -s "$item" -j RETURN
    done
}

add_interface_bypass_rules() {
    chain="$1"
    list_interfaces | while IFS= read -r item || [ -n "$item" ]; do
        case "$item" in ""|\#*) continue ;; esac
        iptables -t mangle -A "$chain" -i "$item" -j RETURN
    done
}

list_items() {
    file="$1"
    [ -f "$file" ] || return 0
    awk '
        {
            sub(/\r$/, "")
            sub(/[[:space:]]#.*/, "")
            item=$1
            sub(/\r$/, "", item)
            if (item != "" && item !~ /^#/) print item
        }
    ' "$file"
}

list_interfaces() {
    list_items "$INTERFACE_EXCLUDE_FILE"
}

show_list() {
    title="$1"
    file="$2"
    print_message "INFO" "$title"
    if [ -n "$(list_items "$file")" ]; then
        i=1
        list_items "$file" | while read item; do
            printf '  %s) %s\n' "$i" "$item"
            i=$((i + 1))
        done
    else
        printf '  %s\n' "list is empty"
    fi
    printf '  file: %s\n' "$file"
}

append_list_items() {
    file="$1"
    shift
    touch "$file"
    for item in "$@"; do
        case "$item" in ""|\#*) continue ;; esac
        grep -qxF "$item" "$file" 2>/dev/null || echo "$item" >> "$file"
    done
}

delete_list_items() {
    file="$1"
    shift
    [ -f "$file" ] || return 0
    tmp="$RUN_DIR/list.tmp"
    cp "$file" "$tmp"
    for item in "$@"; do
        awk -v item="$item" '$0 != item { print }' "$tmp" > "$tmp.new"
        mv "$tmp.new" "$tmp"
    done
    mv "$tmp" "$file"
}

has_include_rules() {
    [ "$(routing_mode)" = "include" ] && [ -n "$(list_items "$ROUTING_FILE")" ]
}

apply_mihomo_target() {
    chain="$1"
    src="$2"
    tproxy_port="$3"

    src_arg=""
    [ -n "$src" ] && src_arg="-s $src"

    iptables -t mangle -A "$chain" -i "$LAN_IF" $src_arg -p tcp -j TPROXY --on-port "$tproxy_port" --tproxy-mark "$FW_MARK"
    iptables -t mangle -A "$chain" -i "$LAN_IF" $src_arg -p udp -j TPROXY --on-port "$tproxy_port" --tproxy-mark "$FW_MARK"
}

add_mihomo_route_rules() {
    chain="$1"
    tproxy_port="$2"

    if has_include_rules; then
        list_items "$ROUTING_FILE" | while read item; do
            apply_mihomo_target "$chain" "$item" "$tproxy_port"
        done
    else
        apply_mihomo_target "$chain" "" "$tproxy_port"
    fi
}

apply_dns_redirect() {
    dns_port="$1"
    iptables -t nat -N "$NAT_CHAIN" 2>/dev/null
    iptables -t nat -F "$NAT_CHAIN"
    iptables -t nat -C PREROUTING -j "$NAT_CHAIN" 2>/dev/null || \
        iptables -t nat -I PREROUTING -j "$NAT_CHAIN"

    list_interfaces | while IFS= read -r item || [ -n "$item" ]; do
        case "$item" in ""|\#*) continue ;; esac
        iptables -t nat -A "$NAT_CHAIN" -i "$item" -p tcp --dport 53 -j RETURN
        iptables -t nat -A "$NAT_CHAIN" -i "$item" -p udp --dport 53 -j RETURN
    done

    if [ "$(routing_mode)" = "exclude" ]; then
        list_items "$ROUTING_FILE" | while read item; do
            iptables -t nat -A "$NAT_CHAIN" -i "$LAN_IF" -s "$item" -p tcp --dport 53 -j RETURN
            iptables -t nat -A "$NAT_CHAIN" -i "$LAN_IF" -s "$item" -p udp --dport 53 -j RETURN
        done
    fi

    if has_include_rules; then
        list_items "$ROUTING_FILE" | while read item; do
            iptables -t nat -A "$NAT_CHAIN" -i "$LAN_IF" -s "$item" -p tcp --dport 53 -j REDIRECT --to-ports "$dns_port"
            iptables -t nat -A "$NAT_CHAIN" -i "$LAN_IF" -s "$item" -p udp --dport 53 -j REDIRECT --to-ports "$dns_port"
        done
    else
        iptables -t nat -A "$NAT_CHAIN" -i "$LAN_IF" -p tcp --dport 53 -j REDIRECT --to-ports "$dns_port"
        iptables -t nat -A "$NAT_CHAIN" -i "$LAN_IF" -p udp --dport 53 -j REDIRECT --to-ports "$dns_port"
    fi
}

apply_rules() {
    if [ "$(proxy_mode)" != "tproxy" ]; then
        flush_rules
        echo "$(proxy_mode)" > "$MODE_FILE"
        log "routing rules skipped: proxy mode=$(proxy_mode)"
        return 0
    fi

    if ! is_running; then
        flush_rules
        log "routing rules skipped: mihomo core is stopped"
        return 0
    fi

    cfg="$(config_file)" || die "missing active config"
    tproxy_port="$(detect_tproxy_port "$cfg")" || die "config $cfg must contain numeric tproxy-port, for example: tproxy-port: 7894"
    dns_port="$(detect_dns_port "$cfg")"
    migrate_routing_list
    route_mode="$(routing_mode)"
    route_items="$(list_items "$ROUTING_FILE")"

    flush_rules
    load_kernel_modules

    iptables -t mangle -N "$MANGLE_CHAIN" 2>/dev/null
    iptables -t mangle -F "$MANGLE_CHAIN"
    iptables -t mangle -C PREROUTING -j "$MANGLE_CHAIN" 2>/dev/null || \
        iptables -t mangle -I PREROUTING -j "$MANGLE_CHAIN"

    add_bypass_rules "$MANGLE_CHAIN"
    add_interface_bypass_rules "$MANGLE_CHAIN"
    add_exclude_rules "$MANGLE_CHAIN"
    iptables -t mangle -A "$MANGLE_CHAIN" -i "$LAN_IF" -p tcp --dport 53 -j RETURN
    iptables -t mangle -A "$MANGLE_CHAIN" -i "$LAN_IF" -p udp --dport 53 -j RETURN

    add_mihomo_route_rules "$MANGLE_CHAIN" "$tproxy_port"
    ip route add local 0.0.0.0/0 dev lo table "$ROUTE_TABLE" 2>/dev/null

    ip rule add fwmark "$FW_MARK" lookup "$ROUTE_TABLE" priority "$RULE_PRIORITY" 2>/dev/null
    apply_dns_redirect "$dns_port"
    echo "tproxy" > "$MODE_FILE"
    log "rules applied: mode=tproxy tproxy_port=$tproxy_port dns_port=$dns_port table=$ROUTE_TABLE mark=$FW_MARK"
    case "$route_mode" in
        include)
            log "routing mode: include ($(printf '%s\n' "$route_items" | awk 'NF { n++ } END { print n + 0 }') item(s))"
            ;;
        exclude)
            log "routing mode: exclude ($(printf '%s\n' "$route_items" | awk 'NF { n++ } END { print n + 0 }') item(s))"
            ;;
        *)
            log "routing mode: off (all LAN clients are routed through Mihomo)"
            ;;
    esac
}
