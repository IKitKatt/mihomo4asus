install_config_setup() {
    while :; do
        printf '\n%s%s%s\n' "$BOLD" "Mihomo config setup" "$RESET"
        printf '  1) Local config\n'
        printf '  2) Subscription URL\n'
        printf '\nSelect config method [1]: '
        read choice
        [ -n "$choice" ] || choice=1
        case "$choice" in
            1)
                save_subscription_settings local "" "$(subscription_update_hours)"
                stop_subscription_updater
                log "put local config to $CONFIG_FILE before start"
                return 0
                ;;
            2)
                printf 'Enter subscription URL: '
                read url
                [ -n "$url" ] || {
                    print_message "WARN" "subscription URL is required"
                    continue
                }
                save_subscription_settings url "$url" "$(subscription_update_hours)"
                if subscription_update_config; then
                    log "subscription config saved to $SUB_CONFIG_FILE"
                    log "config is ready; run: mihomo start"
                    return 0
                fi
                die "subscription config import failed"
                ;;
            *)
                print_message "WARN" "unknown option"
                ;;
        esac
    done
}

exclude_mihomo() {
    ensure_dirs
    migrate_routing_list
    case "$1" in
        show|"")
            show_list "Excluded IP/CIDR list. These clients bypass Mihomo." "$ROUTING_FILE"
            ;;
        clear)
            set_routing_mode exclude
            : > "$ROUTING_FILE"
            print_message "SUCCESS" "excluded IP list cleared"
            printf '%s\n' "excluded IP list cleared" | logger -t mihomo
            is_running && apply_rules
            ;;
        add)
            shift
            set_routing_mode exclude
            [ "$#" -gt 0 ] || die "usage: mihomo exclude add <ip-or-cidr> [more...]"
            append_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "excluded IP list updated"
            printf '%s\n' "excluded IP list updated" | logger -t mihomo
            is_running && apply_rules
            ;;
        del|delete|remove)
            shift
            set_routing_mode exclude
            [ "$#" -gt 0 ] || die "usage: mihomo exclude del <ip-or-cidr> [more...]"
            delete_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "excluded IP list updated"
            printf '%s\n' "excluded IP list updated" | logger -t mihomo
            is_running && apply_rules
            ;;
        set)
            shift
            set_routing_mode exclude
            : > "$ROUTING_FILE"
            append_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "excluded IP list updated"
            printf '%s\n' "excluded IP list updated" | logger -t mihomo
            is_running && apply_rules
            ;;
        *)
            print_message "INFO" "Usage: mihomo exclude {show|add|del|set|clear} [ip-or-cidr...]"
            exit 1
            ;;
    esac
}

include_mihomo() {
    ensure_dirs
    migrate_routing_list
    case "$1" in
        show|"")
            show_list "Included IP/CIDR list. If not empty, only these clients use Mihomo." "$ROUTING_FILE"
            ;;
        clear)
            set_routing_mode include
            : > "$ROUTING_FILE"
            print_message "SUCCESS" "included IP list cleared"
            printf '%s\n' "included IP list cleared" | logger -t mihomo
            is_running && apply_rules
            ;;
        add)
            shift
            set_routing_mode include
            [ "$#" -gt 0 ] || die "usage: mihomo include add <ip-or-cidr> [more...]"
            append_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "included IP list updated"
            printf '%s\n' "included IP list updated" | logger -t mihomo
            is_running && apply_rules
            ;;
        del|delete|remove)
            shift
            set_routing_mode include
            [ "$#" -gt 0 ] || die "usage: mihomo include del <ip-or-cidr> [more...]"
            delete_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "included IP list updated"
            printf '%s\n' "included IP list updated" | logger -t mihomo
            is_running && apply_rules
            ;;
        set)
            shift
            set_routing_mode include
            : > "$ROUTING_FILE"
            append_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "included IP list updated"
            printf '%s\n' "included IP list updated" | logger -t mihomo
            is_running && apply_rules
            ;;
        *)
            print_message "INFO" "Usage: mihomo include {show|add|del|set|clear} [ip-or-cidr...]"
            exit 1
            ;;
    esac
}

subscription_mihomo() {
    ensure_dirs
    cmd="$1"
    case "$cmd" in
        show|"")
            url="$(subscription_setting url)"
            hours="$(subscription_update_hours)"
            sub_type="$(subscription_type)"
            print_message "INFO" "config type: $sub_type"
            if [ "$(subscription_hwid_enabled)" = "1" ]; then
                print_message "INFO" "HWID support: enabled"
            else
                print_message "INFO" "HWID support: disabled"
            fi
            if [ "$(subscription_scan_local)" = "1" ]; then
                print_message "WARN" "local LAN address recovery: enabled"
            else
                print_message "INFO" "local LAN address recovery: disabled"
            fi
            if [ "$sub_type" = "url" ] && [ -n "$url" ]; then
                print_message "INFO" "subscription URL: $(mask_url_for_log "$url")"
                print_message "INFO" "subscription config: $SUB_CONFIG_FILE"
                print_message "INFO" "update interval: ${hours}h"
                last="$(cat "$SUBSCRIPTION_LAST_FILE" 2>/dev/null)"
                case "$last" in
                    ''|*[!0-9]*) print_message "INFO" "last update: never" ;;
                    *) print_message "INFO" "last update epoch: $last" ;;
                esac
            else
                print_message "INFO" "using local config: $CONFIG_FILE"
            fi
            ;;
        local)
            hours="$(subscription_update_hours)"
            save_subscription_settings local "" "$hours"
            rm -f "$SUBSCRIPTION_LAST_FILE"
            stop_subscription_updater
            print_message "SUCCESS" "config type set to local"
            ;;
        set|url)
            shift
            url="$1"
            hours="${2:-$(subscription_update_hours)}"
            [ -n "$url" ] || die "usage: mihomo subscription set <url>"
            save_subscription_settings url "$url" "$hours"
            print_message "SUCCESS" "subscription settings saved"
            printf '%s\n' "subscription settings saved" | logger -t mihomo
            is_running && start_subscription_updater
            ;;
        hours|interval)
            shift
            url="$(subscription_setting url)"
            hours="$1"
            [ -n "$hours" ] || die "usage: mihomo subscription hours <hours>"
            save_subscription_settings "$(subscription_type)" "$url" "$hours"
            print_message "SUCCESS" "subscription interval updated"
            is_running && start_subscription_updater
            ;;
        hwid)
            shift
            value="$1"
            case "$value" in
                ""|show)
                    print_message "INFO" "HWID: $(subscription_hwid)"
                    ;;
                auto|clear)
                    save_subscription_settings "$(subscription_type)" "$(subscription_setting url)" "$(subscription_update_hours)" "" "$(subscription_setting user_agent)" "$(subscription_setting scan_local)"
                    print_message "SUCCESS" "subscription HWID reset to auto"
                    ;;
                *)
                    valid_hwid "$value" || die "subscription HWID must match ^[A-Za-z0-9=-]{10,64}$"
                    save_subscription_settings "$(subscription_type)" "$(subscription_setting url)" "$(subscription_update_hours)" "$value" "$(subscription_setting user_agent)" "$(subscription_setting scan_local)"
                    print_message "SUCCESS" "subscription HWID updated"
                    ;;
            esac
            ;;
        hwid-support)
            shift
            value="$1"
            case "$value" in
                on|1|yes|true|enabled) value=1 ;;
                off|0|no|false|disabled|"") value=0 ;;
                *) die "usage: mihomo subscription hwid-support <on|off>" ;;
            esac
            save_subscription_settings "$(subscription_type)" "$(subscription_setting url)" "$(subscription_update_hours)" "$(subscription_setting hwid)" "$(subscription_setting user_agent)" "$(subscription_setting scan_local)" "$value"
            print_message "SUCCESS" "subscription HWID support updated"
            ;;
        user-agent|ua)
            shift
            value="$*"
            [ -n "$value" ] || {
                print_message "INFO" "user-agent: $(subscription_user_agent)"
                return 0
            }
            save_subscription_settings "$(subscription_type)" "$(subscription_setting url)" "$(subscription_update_hours)" "$(subscription_setting hwid)" "$value" "$(subscription_setting scan_local)" "$(subscription_setting hwid_enabled)"
            print_message "SUCCESS" "subscription user-agent updated"
            ;;
        scan-local)
            shift
            value="$1"
            case "$value" in
                on|1|yes|true|enabled) value=1 ;;
                off|0|no|false|disabled|"") value=0 ;;
                *) die "usage: mihomo subscription scan-local <on|off>" ;;
            esac
            save_subscription_settings "$(subscription_type)" "$(subscription_setting url)" "$(subscription_update_hours)" "$(subscription_setting hwid)" "$(subscription_setting user_agent)" "$value" "$(subscription_setting hwid_enabled)"
            print_message "SUCCESS" "subscription local scan updated"
            ;;
        update)
            subscription_update_and_reload manual
            print_message "SUCCESS" "subscription update completed"
            ;;
        update-auto)
            subscription_update_and_reload auto
            ;;
        clear|disable)
            rm -f "$SUBSCRIPTION_SETTINGS_FILE" "$SUBSCRIPTION_LAST_FILE"
            stop_subscription_updater
            print_message "SUCCESS" "subscription disabled; local config will be used"
            ;;
        *)
            print_message "INFO" "Usage: mihomo subscription {show|local|set|hours|hwid-support|scan-local|update|clear}"
            exit 1
            ;;
    esac
}

status_mihomo() {
    ensure_alias
    arch="$(get_uname -m)"
    if is_running; then
        state="running"
    else
        state="not running"
    fi

    if [ "$state" = "running" ]; then
        print_message "SUCCESS" "mihomo: running"
    else
        print_message "WARN" "mihomo: not running"
    fi
    print_message "INFO" "architecture: $arch"
    [ -x "$MIHOMO_BIN" ] && print_message "INFO" "core: $MIHOMO_BIN"
    version="$(current_version)"
    [ -n "$version" ] && print_message "INFO" "version: $version"
    cfg="$(config_file 2>/dev/null)"
    [ -n "$cfg" ] && print_message "INFO" "active config: $cfg"
    print_message "INFO" "proxy mode: $(proxy_mode)"
    print_message "INFO" "local config: $CONFIG_FILE"
    print_message "INFO" "subscription config: $SUB_CONFIG_FILE"
    subscription_url="$(subscription_setting url)"
    if [ "$(subscription_type)" = "url" ] && [ -n "$subscription_url" ]; then
        print_message "INFO" "subscription: enabled, every $(subscription_update_hours)h"
    else
        print_message "INFO" "subscription: local config"
    fi
    migrate_routing_list
    print_message "INFO" "routing: $(routing_mode), list $ROUTING_FILE"
    if [ -n "$(list_interfaces)" ]; then
        print_message "INFO" "interface bypass list: $(printf '%s' "$(list_interfaces)" | tr '\n' ' ')"
    else
        print_message "INFO" "interface bypass list: empty"
    fi
    if [ -f "$SS_SCRIPT" ] && grep -qF "$SCRIPT_PATH start" "$SS_SCRIPT" 2>/dev/null; then
        print_message "INFO" "autostart: enabled"
    else
        print_message "WARN" "autostart: hook is missing; run mihomo install"
    fi
    print_message "INFO" "core log: $LOG_FILE"
    print_message "INFO" "core log limit: $LOG_MAX_BYTES bytes"
}

log_mihomo() {
    ensure_dirs
    if [ ! -f "$LOG_FILE" ]; then
        : > "$LOG_FILE" || die "cannot create $LOG_FILE"
    fi
    enforce_log_size
    print_message "INFO" "showing $LOG_FILE; press Ctrl+C to stop"
    cat "$LOG_FILE"
    tail -n 0 -f "$LOG_FILE"
}

pause_enter() {
    printf '\nPress Enter to continue... '
    read dummy
}

setup_list_menu() {
    list_name="$1"
    file="$2"
    while :; do
        printf '\n%s%s%s\n' "$BOLD" "Mihomo $list_name IP/CIDR setup" "$RESET"
        show_list "$list_name list" "$file"
        printf '\n'
        printf '  1) Add IP/CIDR\n'
        printf '  2) Delete IP/CIDR\n'
        printf '  3) Replace whole list\n'
        printf '  4) Clear list\n'
        printf '  0) Back\n'
        printf '\nSelect option: '
        read choice
        case "$choice" in
            1)
                printf 'Enter IP/CIDR separated by spaces: '
                read items
                [ -n "$items" ] && append_list_items "$file" $items
                print_message "SUCCESS" "$list_name list updated"
                is_running && apply_rules
                ;;
            2)
                printf 'Enter IP/CIDR to delete, separated by spaces: '
                read items
                [ -n "$items" ] && delete_list_items "$file" $items
                print_message "SUCCESS" "$list_name list updated"
                is_running && apply_rules
                ;;
            3)
                printf 'Enter new IP/CIDR list, separated by spaces: '
                read items
                : > "$file"
                [ -n "$items" ] && append_list_items "$file" $items
                print_message "SUCCESS" "$list_name list replaced"
                is_running && apply_rules
                ;;
            4)
                : > "$file"
                print_message "SUCCESS" "$list_name list cleared"
                is_running && apply_rules
                ;;
            0) return 0 ;;
            *) print_message "WARN" "unknown option" ;;
        esac
    done
}

setup_mihomo() {
    ensure_dirs
    migrate_routing_list
    while :; do
        route_mode="$(routing_mode)"
        printf '\n%s%s%s\n' "$BOLD" "Mihomo routing" "$RESET"
        print_message "INFO" "mode: $route_mode"
        show_list "Routing list" "$ROUTING_FILE"
        printf '\n'
        printf '  1) Switch routing method\n'
        printf '  2) Disable selective routing\n'
        printf '  3) Edit routing list\n'
        printf '  4) Restart routing rules\n'
        printf '  0) Back\n'
        printf '\nSelect option: '
        read choice
        case "$choice" in
            1) routing_method_menu ;;
            2) set_routing_mode off; print_message "SUCCESS" "selective routing disabled"; is_running && apply_rules; pause_enter ;;
            3) setup_list_menu "routing" "$ROUTING_FILE" ;;
            4) apply_rules; pause_enter ;;
            0) return 0 ;;
            *) print_message "WARN" "unknown option" ;;
        esac
    done
}

routing_method_menu() {
    while :; do
        printf '\n%s%s%s\n' "$BOLD" "Switch routing method" "$RESET"
        print_message "INFO" "current mode: $(routing_mode)"
        printf '  1) Include\n'
        printf '  2) Exclude\n'
        printf '  0) Back\n'
        printf '\nSelect option: '
        read choice
        case "$choice" in
            1) set_routing_mode include; print_message "SUCCESS" "routing mode set to include"; is_running && apply_rules; pause_enter; return 0 ;;
            2) set_routing_mode exclude; print_message "SUCCESS" "routing mode set to exclude"; is_running && apply_rules; pause_enter; return 0 ;;
            0) return 0 ;;
            *) print_message "WARN" "unknown option" ;;
        esac
    done
}

show_routed_clients() {
    migrate_routing_list
    route_mode="$(routing_mode)"
    case "$route_mode" in
        include)
            print_message "INFO" "Only these clients are routed through Mihomo:"
            show_list "Routed clients" "$ROUTING_FILE"
            ;;
        exclude)
            print_message "INFO" "All LAN clients are routed through Mihomo except:"
            show_list "Bypass clients" "$ROUTING_FILE"
            ;;
        *)
            print_message "INFO" "All LAN clients are routed through Mihomo."
            printf '  file: %s\n' "$ROUTING_FILE"
            ;;
    esac
}

routing_mihomo() {
    ensure_dirs
    migrate_routing_list
    cmd="$1"
    case "$cmd" in
        show|"")
            print_message "INFO" "routing mode: $(routing_mode)"
            show_routed_clients
            ;;
        mode)
            shift
            [ -n "$1" ] || die "usage: mihomo routing mode <include|exclude|off>"
            set_routing_mode "$1"
            print_message "SUCCESS" "routing mode updated"
            is_running && apply_rules
            ;;
        add)
            shift
            [ "$#" -gt 0 ] || die "usage: mihomo routing add <ip-or-cidr> [more...]"
            append_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "routing list updated"
            is_running && apply_rules
            ;;
        del|delete|remove)
            shift
            [ "$#" -gt 0 ] || die "usage: mihomo routing del <ip-or-cidr> [more...]"
            delete_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "routing list updated"
            is_running && apply_rules
            ;;
        set)
            shift
            : > "$ROUTING_FILE"
            append_list_items "$ROUTING_FILE" "$@"
            print_message "SUCCESS" "routing list replaced"
            is_running && apply_rules
            ;;
        clear)
            : > "$ROUTING_FILE"
            print_message "SUCCESS" "routing list cleared"
            is_running && apply_rules
            ;;
        restart|apply)
            apply_rules
            ;;
        *)
            print_message "INFO" "Usage: mihomo routing {show|mode|add|del|set|clear|restart}"
            exit 1
            ;;
    esac
}

mode_mihomo() {
    ensure_dirs
    cmd="$1"
    case "$cmd" in
        show|"")
            print_message "INFO" "proxy mode: $(proxy_mode)"
            ;;
        set)
            shift
            [ -n "$1" ] || die "usage: mihomo mode set <tproxy|mixed|tun>"
            set_proxy_mode "$1"
            print_message "SUCCESS" "proxy mode updated: $(proxy_mode)"
            if is_running; then
                stop_mihomo
                sleep 2
                start_mihomo
            fi
            ;;
        *)
            print_message "INFO" "Usage: mihomo mode {show|set <tproxy|mixed|tun>}"
            exit 1
            ;;
    esac
}

interfaces_mihomo() {
    ensure_dirs
    cmd="$1"
    case "$cmd" in
        show|"")
            show_list "Bypass interface list. Traffic entering these interfaces bypasses Mihomo." "$INTERFACE_EXCLUDE_FILE"
            ;;
        add)
            shift
            [ "$#" -gt 0 ] || die "usage: mihomo interfaces add <iface> [more...]"
            append_list_items "$INTERFACE_EXCLUDE_FILE" "$@"
            print_message "SUCCESS" "interface bypass list updated"
            is_running && apply_rules
            ;;
        del|delete|remove)
            shift
            [ "$#" -gt 0 ] || die "usage: mihomo interfaces del <iface> [more...]"
            delete_list_items "$INTERFACE_EXCLUDE_FILE" "$@"
            print_message "SUCCESS" "interface bypass list updated"
            is_running && apply_rules
            ;;
        set)
            shift
            mkdir -p "$STATE_DIR" 2>/dev/null || die "cannot create $STATE_DIR"
            : > "$INTERFACE_EXCLUDE_FILE"
            append_list_items "$INTERFACE_EXCLUDE_FILE" "$@"
            print_message "SUCCESS" "interface bypass list replaced"
            is_running && apply_rules
            ;;
        clear)
            mkdir -p "$STATE_DIR" 2>/dev/null || die "cannot create $STATE_DIR"
            : > "$INTERFACE_EXCLUDE_FILE"
            print_message "SUCCESS" "interface bypass list cleared"
            is_running && apply_rules
            ;;
        *)
            print_message "INFO" "Usage: mihomo interfaces {show|add|del|set|clear} [iface...]"
            exit 1
            ;;
    esac
}

usage_mihomo() {
    printf '%s%s%s\n' "$BOLD" "mihomo4asus" "$RESET"
    printf '\n'
    print_message "ACTION" "Service commands"
    printf '  mihomo install       install script, core and boot hooks\n'
    printf '  mihomo start         start Mihomo and apply routing rules\n'
    printf '  mihomo stop          stop Mihomo and remove routing rules\n'
    printf '  mihomo restart       restart Mihomo\n'
    printf '  mihomo status        show core state and architecture\n'
    printf '  mihomo logs          follow Mihomo core log until Ctrl+C\n'
    printf '  mihomo update        open update menu\n'
    printf '  mihomo update core   update Mihomo core if a new version exists\n'
    printf '  mihomo update script update mihomo4asus script from GitHub\n'
    printf '  mihomo reload        reload active config through Mihomo controller\n'
    printf '  mihomo mode          show or switch proxy mode\n'
    printf '  mihomo subscription  configure local config or subscription URL\n'
    printf '\n'
    print_message "ACTION" "Routing lists"
    printf '  mihomo routing show\n'
    printf '  mihomo routing mode <include|exclude|off>\n'
    printf '  mihomo routing add|del|set|clear [ip-or-cidr...]\n'
    printf '  mihomo routing restart\n'
    printf '  mihomo interfaces show|add|del|set|clear [iface...]\n'
    printf '  mihomo mode show|set <tproxy|mixed|tun>\n'
    printf '\n'
    print_message "ACTION" "Subscription config"
    printf '  mihomo subscription show\n'
    printf '  mihomo subscription local\n'
    printf '  mihomo subscription set <url>\n'
    printf '  mihomo subscription hours <hours>\n'
    printf '  mihomo subscription hwid-support <on|off>\n'
    printf '  mihomo subscription scan-local <on|off>\n'
    printf '  mihomo subscription update\n'
    printf '  mihomo subscription clear\n'
    printf '\n'
    print_message "ACTION" "Maintenance"
    printf '  mihomo uninstall     remove core, files, hooks and iptables rules\n'
}

update_menu() {
    ensure_dirs
    while :; do
        printf '\n%s%s%s\n' "$BOLD" "Mihomo update" "$RESET"
        printf '  1) Update core\n'
        printf '  2) Update script\n'
        printf '  0) Back\n'
        printf '\nSelect option: '
        read choice
        case "$choice" in
            1) update_mihomo; pause_enter ;;
            2) update_script; pause_enter ;;
            0) return 0 ;;
            *) print_message "WARN" "unknown option" ;;
        esac
    done
}

subscription_setup_menu() {
    ensure_dirs
    while :; do
        printf '\n%s%s%s\n' "$BOLD" "Mihomo subscription setup" "$RESET"
        subscription_mihomo show
        printf '\n'
        printf '  1) Switch subscription method\n'
        printf '  2) Set subscription URL\n'
        printf '  3) Change update interval\n'
        printf '  4) Update now\n'
        printf '  5) Disable subscription URL\n'
        printf '  0) Back\n'
        printf '\nSelect option: '
        read choice
        case "$choice" in
            1) subscription_method_menu ;;
            2)
                printf 'Enter subscription URL: '
                read url
                subscription_mihomo set "$url"
                pause_enter
                ;;
            3)
                printf 'Update interval in hours: '
                read hours
                subscription_mihomo hours "$hours"
                pause_enter
                ;;
            4) subscription_mihomo update; pause_enter ;;
            5) subscription_mihomo clear; pause_enter ;;
            0) return 0 ;;
            *) print_message "WARN" "unknown option" ;;
        esac
    done
}

subscription_method_menu() {
    while :; do
        printf '\n%s%s%s\n' "$BOLD" "Switch sub method" "$RESET"
        print_message "INFO" "current method: $(subscription_type)"
        printf '  1) Local\n'
        printf '  2) Subscription URL\n'
        printf '  0) Back\n'
        printf '\nSelect option: '
        read choice
        case "$choice" in
            1) subscription_mihomo local; pause_enter; return 0 ;;
            2)
                printf 'Enter subscription URL: '
                read url
                subscription_mihomo set "$url"
                pause_enter
                return 0
                ;;
            0) return 0 ;;
            *) print_message "WARN" "unknown option" ;;
        esac
    done
}

main_menu() {
    while :; do
        printf '\n%s%s%s\n' "$BOLD" "mihomo4asus" "$RESET"
        printf '  1) Status\n'
        printf '  2) Start\n'
        printf '  3) Restart\n'
        printf '  4) Stop\n'
        printf '  5) Update\n'
        printf '  6) Subscription\n'
        printf '  7) Routing\n'
        printf '  8) Logs\n'
        printf '  9) Commands\n'
        printf '  0) Exit\n'
        printf '\nSelect option: '
        read choice
        case "$choice" in
            1) status_mihomo; pause_enter ;;
            2) start_mihomo; pause_enter ;;
            3) stop_mihomo; sleep 2; start_mihomo; pause_enter ;;
            4) stop_mihomo; pause_enter ;;
            5) update_menu ;;
            6) subscription_setup_menu ;;
            7) setup_mihomo ;;
            8) log_mihomo ;;
            9) usage_mihomo; pause_enter ;;
            0) exit 0 ;;
            *) print_message "WARN" "unknown option" ;;
        esac
    done
}
