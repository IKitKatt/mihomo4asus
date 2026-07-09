print_message() {
    type="$1"
    shift
    color="$GRAY"
    case "$type" in
        SUCCESS) color="$GREEN" ;;
        WARN) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        ACTION|LINK) color="$CYAN" ;;
        INFO|*) color="$GRAY" ;;
    esac
    printf '%s[%s]%s %s\n' "$color" "$type" "$RESET" "$*"
}

log() {
    print_message "INFO" "$1"
    printf '%s\n' "$1" | logger -t mihomo
}

get_uname() {
    opt="$1"
    if command -v uname >/dev/null 2>&1; then
        uname "$opt"
    elif [ -x /bin/uname ]; then
        /bin/uname "$opt"
    elif [ -x /usr/bin/uname ]; then
        /usr/bin/uname "$opt"
    elif [ -x /opt/bin/uname ]; then
        /opt/bin/uname "$opt"
    elif command -v busybox >/dev/null 2>&1; then
        busybox uname "$opt"
    elif [ -x /bin/busybox ]; then
        /bin/busybox uname "$opt"
    else
        die "missing uname or busybox uname"
    fi
}

die() {
    print_message "ERROR" "$1"
    printf '%s\n' "ERROR: $1" | logger -t mihomo
    exit 1
}

log_size() {
    [ -f "$LOG_FILE" ] || { echo 0; return 0; }
    wc -c < "$LOG_FILE" 2>/dev/null || echo 0
}

clear_core_log() {
    rm -f "$LOG_FILE" 2>/dev/null
}

enforce_log_size() {
    size="$(log_size)"
    case "$size" in
        ''|*[!0-9]*) size=0 ;;
    esac
    if [ "$size" -gt "$LOG_MAX_BYTES" ] 2>/dev/null; then
        : > "$LOG_FILE" 2>/dev/null
        printf '%s\n' "mihomo log truncated: ${size} bytes exceeded ${LOG_MAX_BYTES} bytes" | logger -t mihomo
    fi
}

start_log_guard() {
    stop_log_guard
    (
        while :; do
            enforce_log_size
            sleep 5
        done
    ) &
    echo "$!" > "$LOG_GUARD_PID_FILE"
}

stop_log_guard() {
    guard_pid="$(cat "$LOG_GUARD_PID_FILE" 2>/dev/null)"
    case "$guard_pid" in
        ''|*[!0-9]*) ;;
        *) kill "$guard_pid" 2>/dev/null ;;
    esac
    rm -f "$LOG_GUARD_PID_FILE"
}

ensure_dirs() {
    [ -d "$ROOT_DIR" ] || die "Entware root $ROOT_DIR is not available"
    mkdir -p "$MIHOMO_HOME" "$CONFIG_DIR" "$RUN_DIR" "$STATE_DIR" || die "cannot create mihomo directories"
    migrate_config_extras
}

ensure_script_dirs() {
    mkdir -p "$(dirname "$SCRIPT_PATH")" /jffs/scripts /jffs/configs || die "cannot create JFFS script directories"
}

migrate_config_extras() {
    [ -d "$CONFIG_DIR" ] || return 0
    [ -d "$STATE_DIR" ] || return 0
    for config_path in "$CONFIG_DIR"/*; do
        [ -e "$config_path" ] || continue
        config_name="${config_path##*/}"
        case "$config_name" in
            config.yaml|sub-config.yaml) continue ;;
        esac
        [ -f "$config_path" ] || continue
        if [ -e "$STATE_DIR/$config_name" ]; then
            mv "$config_path" "$STATE_DIR/$config_name.migrated.$$" 2>/dev/null || true
        else
            mv "$config_path" "$STATE_DIR/$config_name" 2>/dev/null || true
        fi
    done
}

config_file() {
    if [ "$(subscription_type)" = "url" ]; then
        [ -f "$SUB_CONFIG_FILE" ] || return 1
        echo "$SUB_CONFIG_FILE"
        return 0
    fi
    [ -f "$CONFIG_FILE" ] || return 1
    echo "$CONFIG_FILE"
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        pid="$(cat "$PID_FILE" 2>/dev/null)"
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && return 0
    fi
    ps | grep -v grep | grep -q "$MIHOMO_BIN"
}

mihomo_pids() {
    if [ -f "$PID_FILE" ]; then
        pid="$(cat "$PID_FILE" 2>/dev/null)"
        [ -n "$pid" ] && echo "$pid"
    fi
    ps | grep -v grep | grep "$MIHOMO_BIN" | awk '{print $1}'
}

wait_stopped() {
    timeout="$1"
    while [ "$timeout" -gt 0 ]; do
        is_running || return 0
        sleep 1
        timeout=$((timeout - 1))
    done
    return 1
}

yaml_value() {
    key="$1"
    file="$2"
    awk -v key="$key" '
        $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
            sub("^[[:space:]]*" key ":[[:space:]]*", "")
            sub("[[:space:]]#.*$", "")
            gsub(/^["'\'' ]+|["'\'' ]+$/, "")
            print
            exit
        }
    ' "$file"
}

yaml_block_value() {
    block="$1"
    key="$2"
    file="$3"
    awk -v block="$block" -v key="$key" '
        $0 ~ "^[[:space:]]*" block ":[[:space:]]*($|#)" { in_block=1; next }
        in_block && $0 ~ "^[^[:space:]][^:]*:" { exit }
        in_block && $0 ~ "^[[:space:]]+" key ":[[:space:]]*" {
            sub("^[[:space:]]+" key ":[[:space:]]*", "")
            sub("[[:space:]]#.*$", "")
            gsub(/^["'\'' ]+|["'\'' ]+$/, "")
            print
            exit
        }
    ' "$file"
}

detect_tproxy_port() {
    file="$1"
    line="$(grep '^tproxy-port:' "$file" 2>/dev/null | head -n 1)"
    [ -n "$line" ] || return 1

    port="${line#*:}"
    port="${port%%#*}"
    port="$(printf '%s' "$port" | sed 's/^[ 	"]*//;s/[ 	"].*$//;s/\r$//')"

    case "$port" in
        ""|*[!0-9]*)
            return 1
            ;;
    esac

    [ "$port" -gt 0 ] 2>/dev/null || return 1
    [ "$port" -lt 65536 ] 2>/dev/null || return 1
    echo "$port"
}

detect_dns_port() {
    file="$1"
    listen="$(yaml_block_value dns listen "$file")"
    port="$(echo "$listen" | awk -F: '{print $NF}' | awk '{print $1}')"
    if echo "$port" | awk '/^[0-9]+$/ && $1 > 0 && $1 < 65536 { found=1 } END { exit found ? 0 : 1 }'; then
        echo "$port"
    else
        echo "$DNS_PORT"
    fi
}

detect_controller_addr() {
    file="$1"
    line="$(top_level_line external-controller "$file")"
    [ -n "$line" ] || return 1
    addr="${line#*:}"
    addr="${addr%%#*}"
    addr="$(printf '%s' "$addr" | sed 's/^[ 	"'"'"']*//;s/[ 	"'"'"']*$//;s/\r$//')"
    [ -n "$addr" ] || return 1
    printf '%s\n' "$addr"
}

detect_controller_secret() {
    file="$1"
    line="$(top_level_line secret "$file")"
    [ -n "$line" ] || return 1
    secret="${line#*:}"
    secret="${secret%%#*}"
    secret="$(printf '%s' "$secret" | sed 's/^[ 	"'"'"']*//;s/[ 	"'"'"']*$//;s/\r$//')"
    printf '%s\n' "$secret"
}

top_level_line() {
    key="$1"
    file="$2"
    awk -v key="$key" '
        $0 ~ "^" key ":[[:space:]]*" {
            print
            exit
        }
    ' "$file"
}

has_top_level_key() {
    key="$1"
    file="$2"
    grep -q "^$key:" "$file" 2>/dev/null
}

has_top_level_block() {
    key="$1"
    file="$2"
    awk -v key="$key" '
        $0 ~ "^" key ":[[:space:]]*($|#)" { found=1; exit }
        END { exit found ? 0 : 1 }
    ' "$file"
}

extract_top_level_block() {
    key="$1"
    file="$2"
    awk -v key="$key" '
        $0 ~ "^" key ":[[:space:]]*($|#)" {
            in_block=1
            print
            next
        }
        in_block && $0 ~ "^[^[:space:]#][^:]*:[[:space:]]*" { exit }
        in_block { print }
    ' "$file"
}

replace_top_level_key() {
    key="$1"
    line="$2"
    file="$3"
    tmp="$file.key.$$"

    awk -v key="$key" -v line="$line" '
        $0 ~ "^" key ":[[:space:]]*" {
            if (!done) print line
            done=1
            next
        }
        { print }
        END {
            if (!done) print line
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

remove_top_level_key() {
    key="$1"
    file="$2"
    tmp="$file.rmkey.$$"

    awk -v key="$key" '
        $0 ~ "^" key ":[[:space:]]*" { next }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

replace_top_level_block() {
    key="$1"
    block_file="$2"
    file="$3"
    tmp="$file.block.$$"

    awk -v key="$key" -v block_file="$block_file" '
        function print_block() {
            while ((getline block_line < block_file) > 0) print block_line
            close(block_file)
        }
        $0 ~ "^" key ":[[:space:]]*" {
            if (!done) print_block()
            done=1
            skip=1
            next
        }
        skip && $0 ~ "^[^[:space:]#][^:]*:[[:space:]]*" {
            skip=0
        }
        skip { next }
        { print }
        END {
            if (!done) print_block()
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

remove_top_level_block() {
    key="$1"
    file="$2"
    tmp="$file.rmblock.$$"

    awk -v key="$key" '
        $0 ~ "^" key ":[[:space:]]*" {
            skip=1
            next
        }
        skip && $0 ~ "^[^[:space:]#][^:]*:[[:space:]]*" {
            skip=0
        }
        skip { next }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

remove_block_keys() {
    block="$1"
    file="$2"
    shift 2
    keys="$*"
    tmp="$file.rmblockkeys.$$"

    awk -v block="$block" -v keys="$keys" '
        function indent_len(value, prefix) {
            prefix=value
            sub(/[^[:space:]].*$/, "", prefix)
            return length(prefix)
        }
        function key_match(key) {
            return (" " keys " ") ~ (" " key " ")
        }
        {
            line=$0
            is_top=(line ~ /^[^[:space:]#][^:]*:[[:space:]]*/)
            if (is_top) {
                skip=0
                if (line ~ "^" block ":[[:space:]]*($|#)") {
                    in_block=1
                } else {
                    in_block=0
                }
            }
            if (in_block && !is_top) {
                if (skip) {
                    if (line ~ /^[[:space:]]*$/) next
                    current_indent=indent_len(line)
                    if (current_indent > skip_indent) next
                    skip=0
                }
                stripped=line
                sub(/^[[:space:]]+/, "", stripped)
                key=stripped
                sub(/:.*/, "", key)
                if (line ~ /^[[:space:]]+[^[:space:]#][^:]*:[[:space:]]*/ && key_match(key)) {
                    skip=1
                    skip_indent=indent_len(line)
                    next
                }
            }
            print
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

remove_block_key_value() {
    block="$1"
    wanted_key="$2"
    wanted_value="$3"
    file="$4"
    tmp="$file.rmblockvalue.$$"

    awk -v block="$block" -v wanted_key="$wanted_key" -v wanted_value="$wanted_value" '
        function indent_len(value, prefix) {
            prefix=value
            sub(/[^[:space:]].*$/, "", prefix)
            return length(prefix)
        }
        {
            line=$0
            is_top=(line ~ /^[^[:space:]#][^:]*:[[:space:]]*/)
            if (is_top) {
                skip=0
                if (line ~ "^" block ":[[:space:]]*($|#)") {
                    in_block=1
                } else {
                    in_block=0
                }
            }
            if (in_block && !is_top) {
                if (skip) {
                    if (line ~ /^[[:space:]]*$/) next
                    current_indent=indent_len(line)
                    if (current_indent > skip_indent) next
                    skip=0
                }
                stripped=line
                sub(/^[[:space:]]+/, "", stripped)
                key=stripped
                sub(/:.*/, "", key)
                value=stripped
                sub(/^[^:]*:[[:space:]]*/, "", value)
                sub(/[[:space:]]#.*$/, "", value)
                gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", value)
                if (line ~ /^[[:space:]]+[^[:space:]#][^:]*:[[:space:]]*/ &&
                    key == wanted_key && value == wanted_value) {
                    skip=1
                    skip_indent=indent_len(line)
                    next
                }
            }
            print
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

remove_dns_proxy_entries() {
    file="$1"
    names_file="$2"
    tmp="$file.rmdnsproxy.$$"

    : > "$names_file" || return 1
    awk -v names_file="$names_file" '
        function indent_len(value, prefix) {
            prefix=value
            sub(/[^[:space:]].*$/, "", prefix)
            return length(prefix)
        }
        function clean_value(value) {
            sub(/[[:space:]]#.*$/, "", value)
            gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", value)
            return value
        }
        function parse_item_line(line, value) {
            value=line
            sub(/^[[:space:]]+/, "", value)
            if (value ~ /^-[[:space:]]*/) sub(/^-[[:space:]]*/, "", value)
            if (value ~ /^name:[[:space:]]*/) {
                sub(/^name:[[:space:]]*/, "", value)
                item_name=clean_value(value)
            } else if (value ~ /^type:[[:space:]]*/) {
                sub(/^type:[[:space:]]*/, "", value)
                if (clean_value(value) == "dns") item_is_dns=1
            }
        }
        function flush_item(i) {
            if (item_count == 0) return
            if (item_is_dns) {
                if (item_name != "") print item_name >> names_file
            } else {
                for (i=1; i<=item_count; i++) print item_lines[i]
            }
            item_count=0
            item_name=""
            item_is_dns=0
        }
        {
            line=$0
            is_top=(line ~ /^[^[:space:]#][^:]*:[[:space:]]*/)
            if (is_top) {
                if (in_proxies) flush_item()
                if (line ~ /^proxies:[[:space:]]*($|#)/) {
                    in_proxies=1
                    item_indent=-1
                    print
                    next
                }
                in_proxies=0
            }
            if (in_proxies) {
                if (line ~ /^[[:space:]]*-[[:space:]]*/) {
                    current_indent=indent_len(line)
                    if (item_indent < 0 || current_indent == item_indent) {
                        flush_item()
                        item_indent=current_indent
                    }
                }
                if (item_indent >= 0 && indent_len(line) >= item_indent) {
                    item_count++
                    item_lines[item_count]=line
                    parse_item_line(line)
                    next
                }
            }
            print
        }
        END {
            if (in_proxies) flush_item()
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

remove_rules_for_names() {
    file="$1"
    names_file="$2"
    [ -s "$names_file" ] || return 0
    tmp="$file.rmrules.$$"

    awk -v names_file="$names_file" '
        function indent_len(value, prefix) {
            prefix=value
            sub(/[^[:space:]].*$/, "", prefix)
            return length(prefix)
        }
        function has_removed_name(line, i) {
            for (i=1; i<=name_count; i++) {
                if (names[i] != "" && index(line, names[i]) > 0) return 1
            }
            return 0
        }
        BEGIN {
            while ((getline name < names_file) > 0) {
                name_count++
                names[name_count]=name
            }
            close(names_file)
        }
        {
            line=$0
            is_top=(line ~ /^[^[:space:]#][^:]*:[[:space:]]*/)
            if (is_top) {
                skip=0
                if (line ~ /^rules:[[:space:]]*($|#)/) {
                    in_rules=1
                } else {
                    in_rules=0
                }
            }
            if (in_rules && !is_top) {
                if (skip) {
                    if (line ~ /^[[:space:]]*$/) next
                    current_indent=indent_len(line)
                    if (current_indent > skip_indent) next
                    skip=0
                }
                if (has_removed_name(line)) {
                    skip=1
                    skip_indent=indent_len(line)
                    next
                }
            }
            print
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

cleanup_hooks() {
    [ -f "$NAT_SCRIPT" ] && sed -i "/$TAG/d" "$NAT_SCRIPT"
    [ -f "$FW_SCRIPT" ] && sed -i "/$TAG/d" "$FW_SCRIPT"
    [ -f "$SS_SCRIPT" ] && sed -i "/$TAG/d" "$SS_SCRIPT"
}

append_hook_line() {
    file="$1"
    line="$2"
    [ -f "$file" ] || { echo "#!/bin/sh" > "$file"; chmod 755 "$file"; }
    grep -qF "$line" "$file" || echo "$line" >> "$file"
}

download_to_stdout() {
    url="$1"
    wget --quiet --header="Accept: application/vnd.github.v3+json" -O - "$url" 2>/dev/null || \
        curl -fsSL "$url" 2>/dev/null
}

download_to_file() {
    url="$1"
    dst="$2"
    wget -q -O "$dst" "$url" 2>/dev/null || \
        curl -fsSL -o "$dst" "$url" 2>/dev/null
}

find_command_path() {
    cmd="$1"
    found="$(command -v "$cmd" 2>/dev/null)"
    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        return 0
    fi
    for path in "/opt/bin/$cmd" "/usr/bin/$cmd" "/bin/$cmd" "/usr/sbin/$cmd" "/sbin/$cmd"; do
        [ -x "$path" ] && { printf '%s\n' "$path"; return 0; }
    done
    return 1
}

log_http_error() {
    label="$1"
    err_file="$2"
    if [ -s "$err_file" ]; then
        err_line="$(awk 'NF { line=$0 } END { print line }' "$err_file" 2>/dev/null)"
        [ -n "$err_line" ] && log "$label: $err_line"
    else
        log "$label"
    fi
}

mask_url_for_log() {
    url="$1"
    case "$url" in
        *\?*) printf '%s?***\n' "${url%%\?*}" ;;
        *) printf '%s\n' "$url" ;;
    esac
}

url_host() {
    url="$1"
    host="${url#*://}"
    host="${host%%/*}"
    host="${host%%:*}"
    printf '%s\n' "$host"
}

url_port() {
    url="$1"
    scheme="${url%%://*}"
    rest="${url#*://}"
    host_port="${rest%%/*}"
    port="${host_port##*:}"

    if [ "$port" != "$host_port" ]; then
        printf '%s\n' "$port"
        return 0
    fi
    case "$scheme" in
        http) printf '%s\n' "80" ;;
        *) printf '%s\n' "443" ;;
    esac
}

latest_version() {
    download_to_stdout "$MIHOMO_API" | awk '
        /"tag_name":/ {
            tag=$0
            gsub(/^.*"tag_name":[[:space:]]*"/, "", tag)
            gsub(/".*$/, "", tag)
            sub(/^v/, "", tag)
            print tag
            exit
        }
    '
}

current_version() {
    [ -x "$MIHOMO_BIN" ] || return 1
    "$MIHOMO_BIN" -v 2>/dev/null | awk '
        {
            for (i=1; i<=NF; i++) {
                if ($i ~ /^v?[0-9]+\.[0-9]+\.[0-9]+/) {
                    gsub(/^v/, "", $i)
                    gsub(/[^0-9A-Za-z.+_-].*$/, "", $i)
                    print $i
                    exit
                }
            }
        }
    '
}

script_version_from_file() {
    file="$1"
    awk -F= '
        /^SCRIPT_VERSION=/ {
            version=$2
            gsub(/^["'\'' ]+|["'\'' ]+$/, "", version)
            print version
            exit
        }
    ' "$file"
}

unpack_gz() {
    src="$1"
    dst="$2"
    gzip -dc "$src" > "$dst" 2>/dev/null || \
        gunzip -c "$src" > "$dst" 2>/dev/null || \
        zcat "$src" > "$dst" 2>/dev/null
}

detect_asset_pattern() {
    arch="$(get_uname -m)"
    case "$arch" in
        aarch64|arm64)
            echo 'mihomo-linux-arm64-[^"]*\.gz'
            ;;
        armv7*|armv7l)
            echo 'mihomo-linux-armv7-[^"]*\.gz'
            ;;
        *)
            die "unsupported CPU architecture: $arch"
            ;;
    esac
}

latest_download_url() {
    pattern="$(detect_asset_pattern)"
    download_to_stdout "$MIHOMO_API" | awk -v pattern="$pattern" '
        /"browser_download_url":/ {
            url=$0
            gsub(/^.*"browser_download_url":[[:space:]]*"/, "", url)
            gsub(/".*$/, "", url)
            if (url ~ pattern &&
                url !~ /android/ &&
                url !~ /freebsd/ &&
                url !~ /darwin/ &&
                url !~ /windows/ &&
                url !~ /compatible/ &&
                url !~ /go[0-9]+/) {
                print url
                exit
            }
        }
    '
}
