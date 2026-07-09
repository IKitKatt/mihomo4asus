#!/bin/sh

# Installer for mihomo4asus.
# Override RAW_BASE if you publish from another repository/branch:
# RAW_BASE=https://raw.githubusercontent.com/<user>/<repo>/<branch> sh install.sh

RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/IKitKatt/mihomo4asus/web}"
INSTALLER_URL="${INSTALLER_URL:-$RAW_BASE/install-app.sh}"
INSTALLER_PATH="${INSTALLER_PATH:-/tmp/mihomo4asus-install-app.sh}"

download_to_file() {
    url="$1"
    dst="$2"
    wget -q -O "$dst" "$url" 2>/dev/null || \
        curl -fsSL -o "$dst" "$url" 2>/dev/null
}

mkdir -p "$(dirname "$INSTALLER_PATH")" || {
    echo "ERROR: cannot create $(dirname "$INSTALLER_PATH")"
    exit 1
}

echo "Downloading $INSTALLER_URL"
download_to_file "$INSTALLER_URL" "$INSTALLER_PATH" || {
    echo "ERROR: cannot download application installer"
    exit 1
}

chmod 755 "$INSTALLER_PATH" || {
    echo "ERROR: cannot chmod $INSTALLER_PATH"
    exit 1
}

exec sh "$INSTALLER_PATH"
