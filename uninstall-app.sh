#!/bin/sh

# Non-interactive uninstaller for mihomo4asus application.
# Removes web service, Merlin addon page, Mihomo core files, state and hooks.

ADDON_DIR="${ADDON_DIR:-/jffs/addons/mihomo}"
MIHOMO_HOME="${MIHOMO_HOME:-/opt/root/mihomo}"
SCRIPT_PATH="${SCRIPT_PATH:-$ADDON_DIR/mihomo}"
LN_PATH="${LN_PATH:-/opt/bin/mihomo}"
WEB_CTL="$ADDON_DIR/webui/mihomo-web"
SS_SCRIPT="${SS_SCRIPT:-/jffs/scripts/services-start}"
NAT_SCRIPT="${NAT_SCRIPT:-/jffs/scripts/nat-start}"
FW_SCRIPT="${FW_SCRIPT:-/jffs/scripts/firewall-start}"
TAG="mihomo-script"
WEB_TAG="mihomo-web"

remove_tagged_lines() {
    file="$1"
    tag="$2"
    [ -f "$file" ] || return 0
    tmp="/tmp/mihomo-uninstall-hook.$$"
    grep -Fv "$tag" "$file" > "$tmp"
    status=$?
    [ "$status" -le 1 ] || { rm -f "$tmp"; return 1; }
    cat "$tmp" > "$file" || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
}

stop_by_pidfile() {
    pid_file="$1"
    pid="$(cat "$pid_file" 2>/dev/null)"
    case "$pid" in
        ''|*[!0-9]*) ;;
        *) kill "$pid" 2>/dev/null ;;
    esac
    rm -f "$pid_file"
}

if [ -x "$WEB_CTL" ]; then
    "$WEB_CTL" uninstall 2>/dev/null || true
fi

if [ -x "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" stop 2>/dev/null || true
fi

stop_by_pidfile "$MIHOMO_HOME/run/mihomo.pid"
stop_by_pidfile "$MIHOMO_HOME/run/mihomo-web.pid"
stop_by_pidfile "$MIHOMO_HOME/run/mihomo-log-guard.pid"
stop_by_pidfile "$MIHOMO_HOME/run/mihomo-subscription.pid"

remove_tagged_lines "$SS_SCRIPT" "$TAG"
remove_tagged_lines "$NAT_SCRIPT" "$TAG"
remove_tagged_lines "$FW_SCRIPT" "$TAG"
remove_tagged_lines "$SS_SCRIPT" "$WEB_TAG"

if [ -f "$ADDON_DIR/state/webui.page" ]; then
    page="$(cat "$ADDON_DIR/state/webui.page" 2>/dev/null)"
    [ -n "$page" ] && rm -f "/www/user/$page" "/www/user/${page%.asp}.title"
fi
if [ -f "$MIHOMO_HOME/state/webui.page" ]; then
    page="$(cat "$MIHOMO_HOME/state/webui.page" 2>/dev/null)"
    [ -n "$page" ] && rm -f "/www/user/$page" "/www/user/${page%.asp}.title"
fi
for page in /www/user/user*.asp; do
    [ -f "$page" ] || continue
    grep -q 'page:mihomo' "$page" || continue
    rm -f "$page" "${page%.asp}.title"
done

if [ -f /tmp/menuTree.js ]; then
    sed -i '/tabName: "Mihomo"/d' /tmp/menuTree.js
    umount /www/require/modules/menuTree.js 2>/dev/null || true
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js 2>/dev/null || true
fi

rm -rf /www/user/mihomo
if [ -L /www/MihomoAPP.asp ] && [ "$(readlink /www/MihomoAPP.asp 2>/dev/null)" = "$ADDON_DIR/Mihomo.asp" ]; then
    rm -f /www/MihomoAPP.asp
fi

rm -rf "$ADDON_DIR" "$MIHOMO_HOME"
rm -f "$LN_PATH" /opt/bin/mihomo

if [ -f /jffs/configs/profile.add ]; then
    sed -i "/alias mihomo=.*mihomo/d" /jffs/configs/profile.add
fi

echo "mihomo4asus application removed."
