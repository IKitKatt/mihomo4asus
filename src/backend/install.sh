install_core() {
    mkdir -p "$DOWNLOAD_DIR" || die "cannot create $DOWNLOAD_DIR"
    url="$(latest_download_url)"
    [ -n "$url" ] || die "cannot find suitable Mihomo release asset for $(get_uname -m)"

    archive="$DOWNLOAD_DIR/mihomo.gz"
    tmp_bin="$DOWNLOAD_DIR/mihomo"

    log "downloading $url"
    download_to_file "$url" "$archive" || die "download failed"
    unpack_gz "$archive" "$tmp_bin" || die "cannot unpack $archive"
    chmod 755 "$tmp_bin"
    mv "$tmp_bin" "$MIHOMO_BIN" || die "cannot install $MIHOMO_BIN"
    chmod 755 "$MIHOMO_BIN"
    rm -f "$archive"
}

install_script() {
    ensure_script_dirs
    current="$0"
    if [ "$current" = "$LN_PATH" ]; then
        [ -f "$SCRIPT_PATH" ] || die "missing real script at $SCRIPT_PATH"
        chmod 755 "$SCRIPT_PATH"
    elif [ "$current" != "$SCRIPT_PATH" ]; then
        cp "$current" "$SCRIPT_PATH" || die "cannot copy script to $SCRIPT_PATH"
        chmod 755 "$SCRIPT_PATH"
    else
        chmod 755 "$SCRIPT_PATH"
    fi
    ensure_alias
}

ensure_alias() {
    mkdir -p "$(dirname "$LN_PATH")" 2>/dev/null
    mkdir -p /jffs/configs 2>/dev/null
    rm -f "$LN_PATH" 2>/dev/null
    ln -sf "$SCRIPT_PATH" "$LN_PATH" 2>/dev/null || log "cannot create $LN_PATH symlink"

    profile_add="/jffs/configs/profile.add"
    alias_line="alias mihomo='$SCRIPT_PATH'"
    [ -f "$profile_add" ] || { echo "#!/bin/sh" > "$profile_add"; chmod 755 "$profile_add"; }
    grep -qF "export PATH=/opt/bin:/opt/sbin:" "$profile_add" 2>/dev/null || echo 'export PATH=/opt/bin:/opt/sbin:$PATH' >> "$profile_add"
    grep -qF "$alias_line" "$profile_add" 2>/dev/null || echo "$alias_line" >> "$profile_add"
}

install_hooks() {
    ensure_script_dirs
    ensure_alias
    cleanup_hooks
    append_hook_line "$SS_SCRIPT" "(sleep 45 && $SCRIPT_PATH start) & # $TAG"
    append_hook_line "$NAT_SCRIPT" "(sleep 10 && $SCRIPT_PATH apply-rules) & # $TAG"
    append_hook_line "$FW_SCRIPT" "(sleep 10 && $SCRIPT_PATH apply-rules) & # $TAG"
    append_hook_line "$SE_SCRIPT" "echo \"\$2\" | grep -q \"^mihomo_\" && $SCRIPT_PATH service-event \$(echo \"\$2\" | cut -d'_' -f2- | tr '_' ' ') & # $TAG"
}

install_mihomo() {
    ensure_dirs
    rm -f "$MIHOMO_HOME/mihomo-debug.log" "$RUN_DIR/mihomo-supervisor.pid" "$RUN_DIR/stop.flag" 2>/dev/null
    install_script
    install_core
    log "mihomo installed"
    install_config_setup
}

update_mihomo() {
    ensure_dirs
    ensure_alias
    cur="$(current_version)"
    latest="$(latest_version)"
    [ -n "$latest" ] || die "cannot get latest Mihomo version"

    if [ -n "$cur" ] && [ "$cur" = "$latest" ]; then
        log "mihomo core is up to date: $cur"
        log "no update required"
        return 0
    fi

    [ -n "$cur" ] && log "mihomo core update available: $cur -> $latest" || log "mihomo core update available: $latest"
    stop_mihomo
    rm -f "$MIHOMO_BIN"
    install_core
    start_mihomo
}

update_script() {
    ensure_dirs
    ensure_script_dirs
    mkdir -p "$DOWNLOAD_DIR" || die "cannot create $DOWNLOAD_DIR"

    tmp_script="$DOWNLOAD_DIR/mihomo-script.$$"
    tmp_globals="$DOWNLOAD_DIR/mihomo-globals.$$"
    case "$SCRIPT_RAW_URL" in
        */src/cli/mihomo) raw_base="${SCRIPT_RAW_URL%/src/cli/mihomo}" ;;
        */mihomo) raw_base="${SCRIPT_RAW_URL%/mihomo}" ;;
        *) die "cannot derive repository base from SCRIPT_RAW_URL" ;;
    esac
    rm -f "$tmp_script"
    log "checking script update from $SCRIPT_REPO"
    download_to_file "$SCRIPT_RAW_URL" "$tmp_script" || {
        rm -f "$tmp_script"
        die "cannot download script from $SCRIPT_RAW_URL"
    }
    download_to_file "$raw_base/src/backend/_globals.sh" "$tmp_globals" || {
        rm -f "$tmp_script" "$tmp_globals"
        die "cannot download backend globals from $raw_base"
    }

    latest="$(script_version_from_file "$tmp_globals")"
    [ -n "$latest" ] || {
        rm -f "$tmp_script" "$tmp_globals"
        die "cannot detect remote script version"
    }

    if [ "$SCRIPT_VERSION" = "$latest" ]; then
        rm -f "$tmp_script" "$tmp_globals"
        log "mihomo4asus script is up to date: $SCRIPT_VERSION"
        return 0
    fi

    log "mihomo4asus script update available: $SCRIPT_VERSION -> $latest"
    [ -f "$SCRIPT_PATH" ] && cp "$SCRIPT_PATH" "$SCRIPT_PATH.bak" 2>/dev/null
    mv "$tmp_script" "$SCRIPT_PATH" || {
        rm -f "$tmp_script"
        die "cannot install updated script to $SCRIPT_PATH"
    }
    chmod 755 "$SCRIPT_PATH"
    backend_dir="$(dirname "$SCRIPT_PATH")/src/backend"
    mkdir -p "$backend_dir" || die "cannot create $backend_dir"
    mv "$tmp_globals" "$backend_dir/_globals.sh" || die "cannot install backend globals"
    for module in core subscription routing service install cli main; do
        download_to_file "$raw_base/src/backend/$module.sh" "$backend_dir/$module.sh" || die "cannot download backend module $module"
    done
    chmod 644 "$backend_dir"/*.sh 2>/dev/null
    ensure_alias
    install_hooks
    log "mihomo4asus script updated to $latest"
}

uninstall_mihomo() {
    stop_mihomo
    stop_log_guard
    rm -rf "$MIHOMO_HOME"
    rm -f "$SCRIPT_PATH" "$LN_PATH"
    [ -f /jffs/configs/profile.add ] && sed -i "/alias mihomo=.*mihomo/d" /jffs/configs/profile.add
    rmdir "$(dirname "$SCRIPT_PATH")" 2>/dev/null
    log "mihomo uninstalled"
}
