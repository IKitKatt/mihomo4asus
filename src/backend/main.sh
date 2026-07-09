mihomo_main() {
case "$1" in
    "") main_menu ;;
    install) install_mihomo ;;
    start) start_mihomo ;;
    stop) stop_mihomo ;;
    restart) stop_mihomo; sleep 2; start_mihomo ;;
    reload|reload-config) reload_mihomo_config ;;
    status) status_mihomo ;;
    log|logs) log_mihomo ;;
    update)
        shift
        case "$1" in
            core) update_mihomo ;;
            script) update_script ;;
            ""|menu) update_menu ;;
            *) print_message "INFO" "Usage: mihomo update {core|script}"; exit 1 ;;
        esac
        ;;
    subscription|sub) shift; subscription_mihomo "$@" ;;
    routing|route) shift; routing_mihomo "$@" ;;
    mode) shift; mode_mihomo "$@" ;;
    interfaces|iface) shift; interfaces_mihomo "$@" ;;
    setup) setup_mihomo ;;
    exclude) shift; exclude_mihomo "$@" ;;
    include) shift; include_mihomo "$@" ;;
    uninstall) uninstall_mihomo ;;
    apply-rules) apply_rules ;;
    help|-h|--help) usage_mihomo ;;
    *) usage_mihomo; exit 1 ;;
esac
}
