#!/bin/sh

# Non-interactive installer for mihomo4asus core CLI, Merlin page and Entware web service.
# Usage:
#   sh install-app.sh
#   RAW_BASE=https://raw.githubusercontent.com/<user>/<repo>/<branch> sh install-app.sh

RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/IKitKatt/mihomo4asus/web}"
ADDON_DIR="${ADDON_DIR:-/jffs/addons/mihomo}"
MIHOMO_HOME="${MIHOMO_HOME:-/opt/root/mihomo}"
SCRIPT_PATH="${SCRIPT_PATH:-$ADDON_DIR/mihomo}"
LN_PATH="${LN_PATH:-/opt/bin/mihomo}"
CONFIG_DIR="${CONFIG_DIR:-$MIHOMO_HOME/config}"
STATE_DIR="${STATE_DIR:-$MIHOMO_HOME/state}"
RUN_DIR="${RUN_DIR:-$MIHOMO_HOME/run}"
LOG_FILE="${LOG_FILE:-$MIHOMO_HOME/mihomo.log}"
SS_SCRIPT="${SS_SCRIPT:-/jffs/scripts/services-start}"
NAT_SCRIPT="${NAT_SCRIPT:-/jffs/scripts/nat-start}"
FW_SCRIPT="${FW_SCRIPT:-/jffs/scripts/firewall-start}"
SE_SCRIPT="${SE_SCRIPT:-/jffs/scripts/service-event}"
TAG="mihomo-script"
WEB_TAG="mihomo-web"

die() {
    echo "ERROR: $1" >&2
    exit 1
}

INSTALLER_DIR="$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd)" || die "cannot resolve installer directory"
LOCAL_SOURCE_DIR="${LOCAL_SOURCE_DIR:-$INSTALLER_DIR}"
LOCAL_SOURCES_NOTICE=0

normalize_lf() {
    file="$1"
    [ -f "$file" ] || return 0
    sed -i 's/\r$//' "$file" || die "cannot normalize line endings in $file"
}

normalize_local_installers() {
    for file in "$INSTALLER_DIR/install-app.sh" "$INSTALLER_DIR/install.sh" "$INSTALLER_DIR/uninstall-app.sh"; do
        normalize_lf "$file"
    done
}

download_to_file() {
    url="$1"
    dst="$2"
    curl_path="$(curl_bin 2>/dev/null)"
    if [ -n "$curl_path" ] && "$curl_path" -fL --retry 2 --retry-delay 1 --connect-timeout 10 --max-time 120 -o "$dst" "$url"; then
        return 0
    fi
    wget_path="$(wget_bin 2>/dev/null)"
    [ -n "$wget_path" ] && "$wget_path" -q -O "$dst" "$url"
}

curl_bin() {
    for path in /opt/bin/curl /opt/sbin/curl; do
        [ -x "$path" ] && { printf '%s\n' "$path"; return 0; }
    done
    command -v curl 2>/dev/null
}

wget_bin() {
    for path in /opt/bin/wget /opt/sbin/wget; do
        [ -x "$path" ] && { printf '%s\n' "$path"; return 0; }
    done
    command -v wget 2>/dev/null
}

copy_or_download() {
    src="$1"
    dst="$2"
    mkdir -p "$(dirname "$dst")" || die "cannot create $(dirname "$dst")"
    if [ -d "$LOCAL_SOURCE_DIR/src" ]; then
        if [ "$LOCAL_SOURCES_NOTICE" -eq 0 ]; then
            echo "Using local application sources from $LOCAL_SOURCE_DIR/src"
            LOCAL_SOURCES_NOTICE=1
        fi
        local_src="$LOCAL_SOURCE_DIR/$src"
        [ -f "$local_src" ] || die "missing local source file: $local_src"
    else
        local_src="$src"
    fi
    if [ -f "$local_src" ]; then
        normalize_lf "$local_src"
        src_dir="$(CDPATH= cd "$(dirname "$local_src")" 2>/dev/null && pwd)" || die "cannot resolve source directory for $local_src"
        dst_dir="$(CDPATH= cd "$(dirname "$dst")" 2>/dev/null && pwd)" || die "cannot resolve destination directory for $dst"
        if [ "$src_dir/$(basename "$local_src")" = "$dst_dir/$(basename "$dst")" ]; then
            return 0
        fi
        cp "$local_src" "$dst" || die "cannot copy $local_src"
        normalize_lf "$dst"
    else
        download_to_file "$RAW_BASE/$src" "$dst" || die "cannot download $RAW_BASE/$src"
    fi
}

append_unique_line() {
    file="$1"
    line="$2"
    mkdir -p "$(dirname "$file")" || die "cannot create $(dirname "$file")"
    [ -f "$file" ] || { echo "#!/bin/sh" > "$file"; chmod 755 "$file"; }
    grep -qF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

remove_tagged_lines() {
    file="$1"
    tag="$2"
    [ -f "$file" ] || return 0
    tmp="/tmp/mihomo-install-hook.$$"
    grep -Fv "$tag" "$file" > "$tmp"
    status=$?
    [ "$status" -le 1 ] || { rm -f "$tmp"; return 1; }
    cat "$tmp" > "$file" || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
}

ensure_entware() {
    [ -d /opt ] || die "Entware /opt is not mounted. Install Entware first."

    export PATH="/opt/bin:/opt/sbin:$PATH"
    if [ -x /opt/bin/opkg ]; then
        opkg_bin=/opt/bin/opkg
    elif [ -x /opt/sbin/opkg ]; then
        opkg_bin=/opt/sbin/opkg
    else
        opkg_bin="$(command -v opkg 2>/dev/null)"
    fi
    [ -n "$opkg_bin" ] || die "Entware opkg is not available. Install Entware first."

    need_lighttpd=0
    need_lighttpd_cgi=0
    need_curl=0
    command -v lighttpd >/dev/null 2>&1 || [ -x /opt/sbin/lighttpd ] || [ -x /opt/bin/lighttpd ] || need_lighttpd=1
    [ -f /opt/lib/lighttpd/mod_cgi.so ] || need_lighttpd_cgi=1
    [ -x /opt/bin/curl ] || [ -x /opt/sbin/curl ] || need_curl=1

    if [ "$need_lighttpd" -eq 1 ] || [ "$need_lighttpd_cgi" -eq 1 ] || [ "$need_curl" -eq 1 ]; then
        "$opkg_bin" update || die "Entware package index update failed"
    fi
    if [ "$need_curl" -eq 1 ]; then
        echo "Installing Entware curl package"
        "$opkg_bin" install curl || die "Entware could not install curl"
    fi
    if [ "$need_lighttpd" -eq 1 ]; then
        echo "Installing Entware lighttpd package"
        "$opkg_bin" install lighttpd || die "Entware could not install lighttpd"
    fi
    if [ "$need_lighttpd_cgi" -eq 1 ]; then
        echo "Installing Entware lighttpd CGI module"
        "$opkg_bin" install lighttpd-mod-cgi || die "Entware could not install the lighttpd CGI module"
    fi
    [ -x /opt/bin/curl ] || [ -x /opt/sbin/curl ] || die "Entware curl is required after package installation"
    command -v lighttpd >/dev/null 2>&1 || [ -x /opt/sbin/lighttpd ] || [ -x /opt/bin/lighttpd ] || die "lighttpd is required"
    [ -f /opt/lib/lighttpd/mod_cgi.so ] || die "Entware lighttpd CGI module is required"
}

create_default_config() {
    [ -s "$CONFIG_DIR/config.yaml" ] && return 0
    cat > "$CONFIG_DIR/config.yaml" <<'EOF'
mode: rule
allow-lan: true
bind-address: '*'
mixed-port: 7890
tproxy-port: 7894
find-process-mode: off
external-controller: 0.0.0.0:9090
external-ui-url: https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip
external-ui-name: metacubexd

dns:
  enable: true
  listen: 0.0.0.0:7874
  enhanced-mode: redir-host
  nameserver:
    - 1.1.1.1
    - 8.8.8.8

proxies:
  - name: DIRECT
    type: direct

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT

rules:
  - MATCH,DIRECT
EOF
}

migrate_local_dns_port() {
    file="$CONFIG_DIR/config.yaml"
    [ -s "$file" ] || return 0
    tmp="$RUN_DIR/config-dns-port.$$"
    awk '
        /^dns:[[:space:]]*($|#)/ { in_dns=1 }
        in_dns && /^[^[:space:]#][^:]*:[[:space:]]*/ && $0 !~ /^dns:/ { in_dns=0 }
        in_dns && /^[[:space:]]+listen:[[:space:]]*/ { sub(/:1053/, ":7874") }
        { print }
    ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
    cmp -s "$file" "$tmp" || mv "$tmp" "$file"
    rm -f "$tmp"
}

create_state_files() {
    [ -f "$STATE_DIR/subscription.conf" ] || {
        {
            echo "TYPE=local"
            echo "URL="
            echo "UPDATE_HOURS=1"
            echo "HWID="
            echo "HWID_ENABLED=1"
            echo "USER_AGENT="
            echo "SCAN_LOCAL=0"
        } > "$STATE_DIR/subscription.conf"
        chmod 600 "$STATE_DIR/subscription.conf" 2>/dev/null
    }
    [ -f "$STATE_DIR/routing.mode" ] || echo "exclude" > "$STATE_DIR/routing.mode"
    [ -f "$STATE_DIR/routing.list" ] || : > "$STATE_DIR/routing.list"
    [ -f "$STATE_DIR/proxy.mode" ] || echo "tproxy" > "$STATE_DIR/proxy.mode"
    [ -f "$LOG_FILE" ] || : > "$LOG_FILE"
}

install_alias() {
    mkdir -p "$(dirname "$LN_PATH")" /jffs/configs || die "cannot create shell integration directories"
    rm -f "$LN_PATH" 2>/dev/null
    ln -sf "$SCRIPT_PATH" "$LN_PATH" 2>/dev/null || echo "WARN: cannot create $LN_PATH symlink"

    profile_add="/jffs/configs/profile.add"
    [ -f "$profile_add" ] || { echo "#!/bin/sh" > "$profile_add"; chmod 755 "$profile_add"; }
    grep -qF "export PATH=/opt/bin:/opt/sbin:" "$profile_add" 2>/dev/null || echo 'export PATH=/opt/bin:/opt/sbin:$PATH' >> "$profile_add"
    grep -qF "alias mihomo='$SCRIPT_PATH'" "$profile_add" 2>/dev/null || echo "alias mihomo='$SCRIPT_PATH'" >> "$profile_add"
}

install_hooks() {
    mkdir -p /jffs/scripts || die "cannot create /jffs/scripts"
    remove_tagged_lines "$SS_SCRIPT" "$TAG"
    remove_tagged_lines "$NAT_SCRIPT" "$TAG"
    remove_tagged_lines "$FW_SCRIPT" "$TAG"
    remove_tagged_lines "$SE_SCRIPT" "$TAG"
    append_unique_line "$SS_SCRIPT" "(sleep 45 && $SCRIPT_PATH start) & # $TAG"
    append_unique_line "$NAT_SCRIPT" "(sleep 10 && $SCRIPT_PATH apply-rules) & # $TAG"
    append_unique_line "$FW_SCRIPT" "(sleep 10 && $SCRIPT_PATH apply-rules) & # $TAG"
    append_unique_line "$SE_SCRIPT" "echo \"\$2\" | grep -q \"^mihomo_\" && $SCRIPT_PATH service-event \$(echo \"\$2\" | cut -d'_' -f2- | tr '_' ' ') & # $TAG"
}

install_files() {
    mkdir -p "$ADDON_DIR/src/backend" "$ADDON_DIR/webui/www/cgi-bin" "$CONFIG_DIR" "$STATE_DIR" "$RUN_DIR" || die "cannot create application directories"

    copy_or_download src/cli/mihomo "$SCRIPT_PATH"
    for module in _globals core subscription routing service install cli main; do
        copy_or_download "src/backend/$module.sh" "$ADDON_DIR/src/backend/$module.sh"
    done
    copy_or_download src/frontend/mihomo-web "$ADDON_DIR/webui/mihomo-web"
    copy_or_download src/frontend/server.conf "$ADDON_DIR/webui/server.conf"
    copy_or_download src/frontend/Mihomo.asp "$ADDON_DIR/Mihomo.asp"
    copy_or_download src/frontend/Mihomo.asp "$ADDON_DIR/webui/Mihomo.asp"
    copy_or_download src/frontend/www/index.html "$ADDON_DIR/webui/www/index.html"
    copy_or_download src/frontend/www/app.css "$ADDON_DIR/webui/www/app.css"
    copy_or_download src/frontend/www/app.js "$ADDON_DIR/webui/www/app.js"
    copy_or_download src/frontend/www/cgi-bin/api "$ADDON_DIR/webui/www/cgi-bin/api"

    chmod 755 "$SCRIPT_PATH" "$ADDON_DIR/webui/mihomo-web" "$ADDON_DIR/webui/www/cgi-bin/api"
    chmod 644 "$ADDON_DIR"/src/backend/*.sh
    chmod 644 "$ADDON_DIR/webui/server.conf"
    chmod 644 "$ADDON_DIR/Mihomo.asp" "$ADDON_DIR/webui/Mihomo.asp" "$ADDON_DIR/webui/www/index.html" "$ADDON_DIR/webui/www/app.css" "$ADDON_DIR/webui/www/app.js"

    for file in "$SCRIPT_PATH" "$ADDON_DIR/webui/mihomo-web" "$ADDON_DIR/webui/www/cgi-bin/api"; do
        [ -s "$file" ] || die "missing installed runtime file: $file"
    done
}

normalize_local_installers
ensure_entware
install_files
create_default_config
migrate_local_dns_port
create_state_files
install_alias
install_hooks

if [ ! -x "$MIHOMO_HOME/mihomo" ]; then
    if ! "$SCRIPT_PATH" update core; then
        if [ -x "$MIHOMO_HOME/mihomo" ]; then
            echo "WARN: core was installed but did not start; check $LOG_FILE"
        else
            echo "WARN: core download failed; install can be retried with: mihomo update core"
        fi
    fi
fi
"$ADDON_DIR/webui/mihomo-web" start

lan_ip="$(nvram get lan_ipaddr 2>/dev/null || true)"
[ -n "$lan_ip" ] || lan_ip="router.asus.com"
echo "mihomo4asus application installed."
echo "Open http://$lan_ip:5581/"
