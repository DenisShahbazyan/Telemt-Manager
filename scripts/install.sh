#!/usr/bin/env bash
# Логика установки и переустановки Telemt

# ──────────────────────────────────────────────────────────────────────────────
# Дефолтные значения
# ──────────────────────────────────────────────────────────────────────────────
DEFAULT_PORT="443"
DEFAULT_DOMAIN="github.com"
DEFAULT_USERNAME="user1"

# Глобальная переменная для возврата значений из prompt-функций
PROMPT_RESULT=""

# ──────────────────────────────────────────────────────────────────────────────
# Публичные точки входа
# ──────────────────────────────────────────────────────────────────────────────
run_install() {
    _show_install_mode_menu
}

run_reinstall() {
    log_info "Начало переустановки Telemt..."
    stop_telemt_service
    _download_and_place_binary
    _write_systemd_service_file
    reload_systemd
    enable_telemt_service
    start_telemt_service
    log_success "Переустановка завершена"
    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Подменю режима установки
# ──────────────────────────────────────────────────────────────────────────────
_show_install_mode_menu() {
    while true; do
        clear
        echo -e "${BOLD}── Установка Telemt ──────────────────────────────${NC}"
        echo
        echo -e "  ${BOLD}1)${NC} Автоматическая установка (дефолтные настройки)"
        echo -e "  ${BOLD}2)${NC} Ручная установка (выбор порта, домена и т.д.)"
        echo
        echo -e "  ${BOLD}Enter)${NC} Назад"
        echo
        echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
        echo
        echo -n "  Ваш выбор: "
        read -r mode

        case "$mode" in
            1) _install_auto; return ;;
            2) _install_manual; return ;;
            "") return ;;
            *) log_warn "Неверный выбор. Попробуйте ещё раз."; sleep 1 ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Автоматическая установка
# ──────────────────────────────────────────────────────────────────────────────
_install_auto() {
    log_info "Начало автоматической установки..."

    local port="$DEFAULT_PORT"
    local domain="$DEFAULT_DOMAIN"
    local username="$DEFAULT_USERNAME"
    local secret
    secret=$(_generate_secret)

    if ! _is_port_available "$port"; then
        log_error "Порт $port занят. Используйте ручную установку для выбора другого порта."
        press_enter_to_continue
        return
    fi

    _perform_installation "$port" "$domain" "$username" "$secret"
}

# ──────────────────────────────────────────────────────────────────────────────
# Ручная установка
# ──────────────────────────────────────────────────────────────────────────────
_install_manual() {
    log_info "Начало ручной установки..."

    echo
    _prompt_port;     local port="$PROMPT_RESULT"
    _prompt_domain;   local domain="$PROMPT_RESULT"
    _prompt_username; local username="$PROMPT_RESULT"
    _prompt_secret;   local secret="$PROMPT_RESULT"

    _perform_installation "$port" "$domain" "$username" "$secret"
}

# ──────────────────────────────────────────────────────────────────────────────
# Основная последовательность установки
# ──────────────────────────────────────────────────────────────────────────────
_perform_installation() {
    local port="$1"
    local domain="$2"
    local username="$3"
    local secret="$4"

    echo
    log_info "Скачивание бинарного файла..."
    _download_and_place_binary || return

    log_info "Создание системного пользователя..."
    _create_system_user

    log_info "Создание конфигурации..."
    _create_config_directory
    _write_config_file "$port" "$domain" "$username" "$secret"
    _set_config_ownership

    log_info "Создание systemd службы..."
    _write_systemd_service_file
    reload_systemd

    log_info "Запуск службы..."
    enable_telemt_service
    start_telemt_service

    echo
    log_success "Установка завершена!"
    log_success "Порт: $port  |  Домен: $domain  |  Пользователь: $username"

    _show_proxy_link

    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Бинарный файл
# ──────────────────────────────────────────────────────────────────────────────
_download_and_place_binary() {
    _fetch_binary      || return 1
    _move_binary_to_bin
    _make_binary_executable
}

_fetch_binary() {
    local arch libc url
    arch=$(uname -m)
    libc=$(_detect_libc)
    url="https://github.com/telemt/telemt/releases/latest/download/telemt-${arch}-linux-${libc}.tar.gz"

    log_info "Скачивание: telemt-${arch}-linux-${libc}.tar.gz"
    wget -qO- "$url" | tar -xz -C "$TMP_DIR" || {
        log_error "Не удалось скачать бинарный файл. Проверьте подключение к интернету."
        return 1
    }
}

_detect_libc() {
    if ldd --version 2>&1 | grep -iq musl; then
        echo "musl"
    else
        echo "gnu"
    fi
}

_move_binary_to_bin() {
    sudo mv "$TMP_DIR/telemt" "$TELEMT_BIN"
}

_make_binary_executable() {
    sudo chmod +x "$TELEMT_BIN"
}

# ──────────────────────────────────────────────────────────────────────────────
# Системный пользователь
# ──────────────────────────────────────────────────────────────────────────────
_create_system_user() {
    if id "$TELEMT_SYSTEM_USER" &>/dev/null; then
        log_info "Системный пользователь '$TELEMT_SYSTEM_USER' уже существует"
        return 0
    fi
    sudo useradd -d "$TELEMT_WORKDIR" -m -r -U "$TELEMT_SYSTEM_USER"
}

# ──────────────────────────────────────────────────────────────────────────────
# Конфигурационный файл
# ──────────────────────────────────────────────────────────────────────────────
_create_config_directory() {
    sudo mkdir -p "$TELEMT_CONFIG_DIR"
}

_write_config_file() {
    local port="$1"
    local domain="$2"
    local username="$3"
    local secret="$4"

    sudo tee "$TELEMT_CONFIG_FILE" > /dev/null <<EOF
# === General Settings ===
[general]
# ad_tag = "00000000000000000000000000000000"
use_middle_proxy = false

[general.modes]
classic = false
secure = false
tls = true

[server]
port = ${port}

[server.api]
enabled = true
listen = "${TELEMT_API_LISTEN}"
# whitelist = ["127.0.0.1/32"]
# read_only = true

# === Anti-Censorship & Masking ===
[censorship]
tls_domain = "${domain}"

[access.users]
# format: "username" = "32_hex_chars_secret"
${username} = "${secret}"
EOF
}

_set_config_ownership() {
    sudo chown -R "$TELEMT_SYSTEM_USER:$TELEMT_SYSTEM_USER" "$TELEMT_CONFIG_DIR"
}

# ──────────────────────────────────────────────────────────────────────────────
# Systemd служба
# ──────────────────────────────────────────────────────────────────────────────
_write_systemd_service_file() {
    sudo tee "$TELEMT_SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Telemt
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${TELEMT_SYSTEM_USER}
Group=${TELEMT_SYSTEM_USER}
WorkingDirectory=${TELEMT_WORKDIR}
ExecStart=${TELEMT_BIN} ${TELEMT_CONFIG_FILE}
Restart=on-failure
LimitNOFILE=65536
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
}

# ──────────────────────────────────────────────────────────────────────────────
# Prompt-функции (результат записывается в PROMPT_RESULT)
# ──────────────────────────────────────────────────────────────────────────────
_prompt_port() {
    PROMPT_RESULT=""
    while true; do
        echo -n "  Порт [${DEFAULT_PORT}]: "
        read -r PROMPT_RESULT
        PROMPT_RESULT="${PROMPT_RESULT:-$DEFAULT_PORT}"

        if ! _validate_port_number "$PROMPT_RESULT"; then
            log_warn "Некорректный порт. Введите число от 1 до 65535."
            continue
        fi

        if ! _is_port_available "$PROMPT_RESULT"; then
            log_warn "Порт $PROMPT_RESULT занят. Введите другой порт."
            continue
        fi

        break
    done
}

_prompt_domain() {
    PROMPT_RESULT=""
    echo -n "  TLS домен [${DEFAULT_DOMAIN}]: "
    read -r PROMPT_RESULT
    PROMPT_RESULT="${PROMPT_RESULT:-$DEFAULT_DOMAIN}"
}

_prompt_username() {
    PROMPT_RESULT=""
    echo -n "  Имя пользователя [${DEFAULT_USERNAME}]: "
    read -r PROMPT_RESULT
    PROMPT_RESULT="${PROMPT_RESULT:-$DEFAULT_USERNAME}"
}

_prompt_secret() {
    PROMPT_RESULT=""
    while true; do
        echo
        echo -e "  Секрет (32 hex символа):"
        echo -e "    ${BOLD}1)${NC} Сгенерировать автоматически"
        echo -e "    ${BOLD}2)${NC} Ввести вручную"
        echo -n "  Выбор [1]: "
        read -r choice
        choice="${choice:-1}"

        case "$choice" in
            1)
                PROMPT_RESULT=$(_generate_secret)
                log_success "Сгенерирован секрет: ${BOLD}${PROMPT_RESULT}${NC}"
                return
                ;;
            2)
                _prompt_manual_secret
                return
                ;;
            *)
                log_warn "Неверный выбор."
                ;;
        esac
    done
}

_prompt_manual_secret() {
    while true; do
        echo -n "  Введите секрет (32 hex символа): "
        read -r PROMPT_RESULT

        if _validate_secret "$PROMPT_RESULT"; then
            return
        fi

        log_warn "Неверный формат. Требуется ровно 32 символа из набора 0-9 и a-f."
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Валидаторы
# ──────────────────────────────────────────────────────────────────────────────
_validate_port_number() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

_is_port_available() {
    local port="$1"
    if command -v ss &>/dev/null; then
        ! ss -lnp 2>/dev/null | grep -qE ":${port}[[:space:]]"
    else
        ! sudo netstat -lnp 2>/dev/null | grep -qE ":${port}[[:space:]]"
    fi
}

_validate_secret() {
    local secret="$1"
    [[ "$secret" =~ ^[0-9a-f]{32}$ ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# Ссылка прокси
# ──────────────────────────────────────────────────────────────────────────────
_show_proxy_link() {
    echo
    log_info "Получение ссылки (ожидание готовности API)..."
    local link
    link=$(_fetch_proxy_link)

    if [ -z "$link" ]; then
        log_warn "Не удалось получить ссылку. Попробуйте позже:"
        log_warn "  curl -s http://${TELEMT_API_LISTEN}/v1/users | jq"
        return
    fi

    echo
    echo -e "  ${BOLD}Ваша ссылка:${NC}"
    echo -e "  ${GREEN}${link}${NC}"
}

_fetch_proxy_link() {
    local link
    local max_attempts=30

    for _ in $(seq 1 "$max_attempts"); do
        link=$(
            curl -s "http://${TELEMT_API_LISTEN}/v1/users" 2>/dev/null \
                | jq -r '.data[0].links.tls[0] // empty' 2>/dev/null
        )

        if [ -n "$link" ] && ! echo "$link" | grep -q 'server=0\.0\.0\.0'; then
            echo "$link"
            return
        fi

        sleep 1
    done

    # Не дождались реального IP — возвращаем что есть
    echo "$link"
}

# ──────────────────────────────────────────────────────────────────────────────
# Генераторы
# ──────────────────────────────────────────────────────────────────────────────
_generate_secret() {
    openssl rand -hex 16
}
