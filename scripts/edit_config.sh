#!/usr/bin/env bash
# Редактирование конфигурации Telemt

run_edit_config() {
    if [ ! -f "$TELEMT_CONFIG_FILE" ]; then
        log_warn "$MSG_CONFIG_NOT_FOUND"
        press_enter_to_continue
        return
    fi

    log_info "$MSG_EDITING_CONFIG"
    sudo nano "$TELEMT_CONFIG_FILE"

    restart_telemt_service

    press_enter_to_continue
}
