#!/usr/bin/env bash
# Логика обновления бинарного файла Telemt

# ──────────────────────────────────────────────────────────────────────────────
# Публичная точка входа
# ──────────────────────────────────────────────────────────────────────────────
run_update() {
    if ! is_telemt_installed; then
        log_warn "$MSG_NOT_INSTALLED_UPDATE"
        press_enter_to_continue
        return
    fi

    local current_ver latest_ver
    current_ver=$(get_installed_version)
    latest_ver=$(get_latest_version)

    echo
    # shellcheck disable=SC2059
    log_info "$(printf "$MSG_CURRENT_VERSION" "${current_ver:-N/A}")"
    # shellcheck disable=SC2059
    log_info "$(printf "$MSG_LATEST_VERSION" "$latest_ver")"

    if [ -n "$current_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
        echo
        # shellcheck disable=SC2059
        log_success "$(printf "$MSG_ALREADY_LATEST" "$current_ver")"
        press_enter_to_continue
        return
    fi

    echo
    # shellcheck disable=SC2059
    if ! confirm_action "$(printf "$MSG_CONFIRM_UPDATE" "$latest_ver")"; then
        log_info "$MSG_UPDATE_CANCELLED"
        press_enter_to_continue
        return
    fi

    _perform_update
}

# ──────────────────────────────────────────────────────────────────────────────
# Основная последовательность обновления
# ──────────────────────────────────────────────────────────────────────────────
_perform_update() {
    echo
    stop_telemt_service

    log_info "$MSG_DOWNLOADING_NEW"
    _download_and_place_binary || {
        log_error "$MSG_UPDATE_DOWNLOAD_FAILED"
        start_telemt_service
        press_enter_to_continue
        return
    }

    restart_telemt_service

    echo
    # shellcheck disable=SC2059
    log_success "$(printf "$MSG_UPDATE_DONE" "$(get_installed_version)")"
    press_enter_to_continue
}
