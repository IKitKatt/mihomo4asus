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
TAG="mihomo-script"
WEB_TAG="mihomo-web"

die() {
    echo "ERROR: $1" >&2
    exit 1
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
    if [ -f "$src" ]; then
        src_dir="$(CDPATH= cd -- "$(dirname -- "$src")" 2>/dev/null && pwd)" || die "cannot resolve source directory for $src"
        dst_dir="$(CDPATH= cd -- "$(dirname -- "$dst")" 2>/dev/null && pwd)" || die "cannot resolve destination directory for $dst"
        if [ "$src_dir/$(basename -- "$src")" = "$dst_dir/$(basename -- "$dst")" ]; then
            return 0
        fi
        cp "$src" "$dst" || die "cannot copy $src"
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
    sed -i "/$tag/d" "$file"
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
    need_curl=0
    command -v lighttpd >/dev/null 2>&1 || [ -x /opt/sbin/lighttpd ] || [ -x /opt/bin/lighttpd ] || need_lighttpd=1
    [ -x /opt/bin/curl ] || [ -x /opt/sbin/curl ] || need_curl=1

    if [ "$need_lighttpd" -eq 1 ] || [ "$need_curl" -eq 1 ]; then
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
    [ -x /opt/bin/curl ] || [ -x /opt/sbin/curl ] || die "Entware curl is required after package installation"
    command -v lighttpd >/dev/null 2>&1 || [ -x /opt/sbin/lighttpd ] || [ -x /opt/bin/lighttpd ] || die "lighttpd is required"
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
  listen: 0.0.0.0:1053
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
    append_unique_line "$SS_SCRIPT" "(sleep 45 && $SCRIPT_PATH start) & # $TAG"
    append_unique_line "$NAT_SCRIPT" "(sleep 10 && $SCRIPT_PATH apply-rules) & # $TAG"
    append_unique_line "$FW_SCRIPT" "(sleep 10 && $SCRIPT_PATH apply-rules) & # $TAG"
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
}

ensure_entware
install_files
create_default_config
create_state_files
install_alias
install_hooks

if [ ! -x "$MIHOMO_HOME/mihomo" ]; then
    "$SCRIPT_PATH" update core || echo "WARN: core download failed; install can be retried with: mihomo update core"
fi
"$ADDON_DIR/webui/mihomo-web" start

lan_ip="$(nvram get lan_ipaddr 2>/dev/null || true)"
[ -n "$lan_ip" ] || lan_ip="router.asus.com"
echo "mihomo4asus application installed."
echo "Open http://$lan_ip:5581/"
