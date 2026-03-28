#!/usr/bin/env bash
# Логика удаления Telemt

# ──────────────────────────────────────────────────────────────────────────────
# Публичная точка входа
# ──────────────────────────────────────────────────────────────────────────────
run_uninstall() {
    if ! is_telemt_installed; then
        log_warn "Telemt не установлен."
        press_enter_to_continue
        return
    fi

    echo
    log_warn "Это действие полностью удалит Telemt с вашего сервера."
    echo

    if ! confirm_action "Вы уверены, что хотите удалить Telemt?"; then
        log_info "Удаление отменено."
        press_enter_to_continue
        return
    fi

    local preserve_config
    if confirm_action "Сохранить конфигурацию (${TELEMT_CONFIG_DIR}/)?"; then
        preserve_config="yes"
    else
        preserve_config="no"
    fi

    _perform_uninstall "$preserve_config"
}

# ──────────────────────────────────────────────────────────────────────────────
# Основная последовательность удаления
# ──────────────────────────────────────────────────────────────────────────────
_perform_uninstall() {
    local preserve_config="$1"

    echo
    log_info "Остановка и отключение службы..."
    _stop_and_disable_service

    log_info "Удаление файла службы..."
    _remove_service_file
    reload_systemd
    reset_failed_systemd

    log_info "Удаление бинарного файла..."
    _remove_binary

    if [ "$preserve_config" = "no" ]; then
        log_info "Удаление конфигурации..."
        _remove_config_directory
    else
        log_info "Конфигурация сохранена: ${TELEMT_CONFIG_DIR}/"
    fi

    log_info "Удаление системного пользователя..."
    _remove_system_user

    echo
    log_success "Telemt успешно удалён."
    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Отдельные шаги удаления
# ──────────────────────────────────────────────────────────────────────────────
_stop_and_disable_service() {
    stop_telemt_service
    disable_telemt_service
}

_remove_service_file() {
    [ -f "$TELEMT_SERVICE_FILE" ] || return 0
    sudo rm -f "$TELEMT_SERVICE_FILE"
}

_remove_binary() {
    [ -f "$TELEMT_BIN" ] || return 0
    sudo rm -f "$TELEMT_BIN"
}

_remove_config_directory() {
    [ -d "$TELEMT_CONFIG_DIR" ] || return 0
    sudo rm -rf "$TELEMT_CONFIG_DIR"
}

_remove_system_user() {
    id "$TELEMT_SYSTEM_USER" &>/dev/null || return 0
    sudo userdel -r "$TELEMT_SYSTEM_USER" 2>/dev/null \
        || sudo userdel "$TELEMT_SYSTEM_USER" 2>/dev/null \
        || true
}
