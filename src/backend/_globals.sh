#!/bin/sh

# Minimal Mihomo TProxy runner for ASUSWRT-Merlin + Entware.
# Public commands: install, start, stop, restart, status, log, update, setup, include, exclude, uninstall.

MIHOMO_SCRIPT_DEPTH="${MIHOMO_SCRIPT_DEPTH:-0}"
MIHOMO_SCRIPT_DEPTH=$((MIHOMO_SCRIPT_DEPTH + 1))
export MIHOMO_SCRIPT_DEPTH
[ "$MIHOMO_SCRIPT_DEPTH" -lt 4 ] || { echo "ERROR: recursive mihomo script invocation"; exit 1; }

MIHOMO_HOME="${MIHOMO_HOME:-/opt/root/mihomo}"
ROOT_DIR="${ROOT_DIR:-/opt/root}"
MIHOMO_BIN="${MIHOMO_BIN:-$MIHOMO_HOME/mihomo}"
MIHOMO_REPO="${MIHOMO_REPO:-MetaCubeX/mihomo}"
MIHOMO_API="${MIHOMO_API:-https://api.github.com/repos/$MIHOMO_REPO/releases/latest}"
SCRIPT_REPO="${SCRIPT_REPO:-IKitKatt/mihomo4asus}"
SCRIPT_BRANCH="${SCRIPT_BRANCH:-main}"
SCRIPT_RAW_URL="${SCRIPT_RAW_URL:-https://raw.githubusercontent.com/$SCRIPT_REPO/$SCRIPT_BRANCH/src/cli/mihomo}"
CONFIG_DIR="${CONFIG_DIR:-$MIHOMO_HOME/config}"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SUB_CONFIG_FILE="${SUB_CONFIG_FILE:-$CONFIG_DIR/sub-config.yaml}"
RUN_DIR="${RUN_DIR:-$MIHOMO_HOME/run}"
STATE_DIR="${STATE_DIR:-$MIHOMO_HOME/state}"
LOG_FILE="${LOG_FILE:-$MIHOMO_HOME/mihomo.log}"
LOG_MAX_BYTES="${LOG_MAX_BYTES:-3145728}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$MIHOMO_HOME/download}"
SCRIPT_VERSION="${SCRIPT_VERSION:-1.0.0}"

SCRIPT_PATH="${SCRIPT_PATH:-/jffs/addons/mihomo/mihomo}"
LN_PATH="${LN_PATH:-/opt/bin/mihomo}"
NAT_SCRIPT="${NAT_SCRIPT:-/jffs/scripts/nat-start}"
FW_SCRIPT="${FW_SCRIPT:-/jffs/scripts/firewall-start}"
SS_SCRIPT="${SS_SCRIPT:-/jffs/scripts/services-start}"

LAN_IF="${LAN_IF:-br0}"
ROUTE_TABLE="${ROUTE_TABLE:-5554}"
FW_MARK="${FW_MARK:-0x4d3c2b1b}"
RULE_PRIORITY="${RULE_PRIORITY:-5354}"
DNS_PORT="${DNS_PORT:-1053}"
ROUTING_FILE="${ROUTING_FILE:-$STATE_DIR/routing.list}"
ROUTING_MODE_FILE="${ROUTING_MODE_FILE:-$STATE_DIR/routing.mode}"
EXCLUDE_FILE="${EXCLUDE_FILE:-$STATE_DIR/exclude.list}"
INCLUDE_FILE="${INCLUDE_FILE:-$STATE_DIR/include.list}"
INTERFACE_EXCLUDE_FILE="${INTERFACE_EXCLUDE_FILE:-$STATE_DIR/interface.exclude}"
PROXY_MODE_FILE="${PROXY_MODE_FILE:-$STATE_DIR/proxy.mode}"

TAG="mihomo-script"
MANGLE_CHAIN="MIHOMO-MANGLE"
NAT_CHAIN="MIHOMO-NAT"
PID_FILE="$RUN_DIR/mihomo.pid"
LOG_GUARD_PID_FILE="$RUN_DIR/mihomo-log-guard.pid"
SUBSCRIPTION_PID_FILE="$RUN_DIR/mihomo-subscription.pid"
SUBSCRIPTION_SETTINGS_FILE="$STATE_DIR/subscription.conf"
SUBSCRIPTION_LAST_FILE="$STATE_DIR/subscription.last"
SUBSCRIPTION_HWID_DATE_FILE="$STATE_DIR/hwid.date"
SUBSCRIPTION_PROFILE_INTERVAL_FILE="$RUN_DIR/subscription.profile-update-interval"
SUBSCRIPTION_CONNECT_TIMEOUT="${SUBSCRIPTION_CONNECT_TIMEOUT:-8}"
SUBSCRIPTION_MAX_TIME="${SUBSCRIPTION_MAX_TIME:-30}"
SUBSCRIPTION_SCAN_LIMIT="${SUBSCRIPTION_SCAN_LIMIT:-16}"
MODE_FILE="$RUN_DIR/mode"

if [ -t 1 ]; then
    RED="$(printf '\033[31m')"
    GREEN="$(printf '\033[32m')"
    YELLOW="$(printf '\033[33m')"
    GRAY="$(printf '\033[37m')"
    CYAN="$(printf '\033[36m')"
    BOLD="$(printf '\033[1m')"
    RESET="$(printf '\033[0m')"
else
    RED=""
    GREEN=""
    YELLOW=""
    GRAY=""
    CYAN=""
    BOLD=""
    RESET=""
fi
