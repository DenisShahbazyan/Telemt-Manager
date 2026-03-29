#!/usr/bin/env bash
# Управление метриками Telemt

TELEMT_METRICS_PORT="9090"

# ──────────────────────────────────────────────────────────────────────────────
# Публичная точка входа
# ──────────────────────────────────────────────────────────────────────────────
run_metrics() {
    if ! is_telemt_installed; then
        log_warn "$MSG_NOT_INSTALLED_WARN"
        press_enter_to_continue
        return
    fi

    if _is_metrics_enabled; then
        _disable_metrics
    else
        _enable_metrics
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Проверка состояния
# ──────────────────────────────────────────────────────────────────────────────
_is_metrics_enabled() {
    grep -q "^metrics_port" "$TELEMT_CONFIG_FILE" 2>/dev/null
}

# ──────────────────────────────────────────────────────────────────────────────
# Включение метрик
# ──────────────────────────────────────────────────────────────────────────────
_enable_metrics() {
    echo
    echo -n "  ${MSG_METRICS_PROMPT_IP} "
    read -r user_ip
    user_ip="${user_ip:-0.0.0.0/0}"

    _metrics_add_to_config "$user_ip" || {
        log_error "$MSG_METRICS_CONFIG_ERROR"
        press_enter_to_continue
        return
    }

    systemctl is-active --quiet telemt 2>/dev/null && restart_telemt_service || true

    # shellcheck disable=SC2059
    log_success "$(printf "$MSG_METRICS_ENABLED" "$TELEMT_METRICS_PORT" "$user_ip")"
    _show_metrics_links
    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Отключение метрик
# ──────────────────────────────────────────────────────────────────────────────
_disable_metrics() {
    _metrics_remove_from_config || {
        log_error "$MSG_METRICS_CONFIG_ERROR"
        press_enter_to_continue
        return
    }

    systemctl is-active --quiet telemt 2>/dev/null && restart_telemt_service || true

    log_success "$MSG_METRICS_DISABLED"
    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Отображение ссылок на метрики
# ──────────────────────────────────────────────────────────────────────────────
_show_metrics_links() {
    local server_ip public_host

    server_ip=$(ip route get 1.1.1.1 2>/dev/null \
        | grep -oP 'src \K\S+' | head -1 || true)
    # Запасной вариант: первый IP из hostname -I
    if [ -z "$server_ip" ]; then
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi

    public_host=$(grep '^public_host = ' "$TELEMT_CONFIG_FILE" 2>/dev/null \
        | sed 's/^public_host = "\(.*\)"/\1/' | head -1 || true)

    echo
    echo -e "  ${BOLD}${MSG_METRICS_LINKS_HEADER}${NC}"

    if [ -n "$server_ip" ]; then
        echo -e "  ${GREEN}http://${server_ip}:${TELEMT_METRICS_PORT}/metrics${NC}"
    fi

    if [ -n "$public_host" ]; then
        echo -e "  ${GREEN}http://${public_host}:${TELEMT_METRICS_PORT}/metrics${NC}"
    fi

    if [ -z "$server_ip" ] && [ -z "$public_host" ]; then
        echo -e "  ${YELLOW}http://<SERVER_IP>:${TELEMT_METRICS_PORT}/metrics${NC}"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Запись метрик в конфиг (вставка после строки port = в секции [server])
# ──────────────────────────────────────────────────────────────────────────────
_metrics_add_to_config() {
    local user_ip="$1"
    local tmp
    tmp=$(mktemp)

    awk -v mport="$TELEMT_METRICS_PORT" -v ip="$user_ip" '
        /^port = / {
            print
            print "metrics_port = " mport
            printf "metrics_whitelist = [\"127.0.0.1/32\", \"::1/128\", \"%s\"]\n", ip
            next
        }
        { print }
    ' "$TELEMT_CONFIG_FILE" > "$tmp"

    sudo cp "$tmp" "$TELEMT_CONFIG_FILE"
    sudo chown "${TELEMT_SYSTEM_USER}:${TELEMT_SYSTEM_USER}" "$TELEMT_CONFIG_FILE"
    rm -f "$tmp"
}

# ──────────────────────────────────────────────────────────────────────────────
# Удаление метрик из конфига
# ──────────────────────────────────────────────────────────────────────────────
_metrics_remove_from_config() {
    local tmp
    tmp=$(mktemp)

    grep -v -E '^metrics_port = |^metrics_whitelist = ' "$TELEMT_CONFIG_FILE" > "$tmp"

    sudo cp "$tmp" "$TELEMT_CONFIG_FILE"
    sudo chown "${TELEMT_SYSTEM_USER}:${TELEMT_SYSTEM_USER}" "$TELEMT_CONFIG_FILE"
    rm -f "$tmp"
}
