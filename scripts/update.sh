#!/usr/bin/env bash
# Логика обновления бинарного файла Telemt

# ──────────────────────────────────────────────────────────────────────────────
# Публичная точка входа
# ──────────────────────────────────────────────────────────────────────────────
run_update() {
    if ! is_telemt_installed; then
        log_warn "Telemt не установлен. Сначала выполните установку."
        press_enter_to_continue
        return
    fi

    local current_ver latest_ver
    current_ver=$(get_installed_version)
    latest_ver=$(get_latest_version)

    echo
    log_info "Текущая версия:  ${current_ver:-неизвестна}"
    log_info "Актуальная:      ${latest_ver}"

    if [ -n "$current_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
        echo
        log_success "У вас уже установлена актуальная версия: $current_ver"
        press_enter_to_continue
        return
    fi

    echo
    if ! confirm_action "Обновить Telemt до версии ${latest_ver}?"; then
        log_info "Обновление отменено."
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

    log_info "Скачивание новой версии..."
    _download_and_place_binary || {
        log_error "Не удалось скачать новый бинарный файл. Запуск предыдущей версии..."
        start_telemt_service
        press_enter_to_continue
        return
    }

    restart_telemt_service

    echo
    log_success "Обновление завершено. Установленная версия: $(get_installed_version)"
    press_enter_to_continue
}
