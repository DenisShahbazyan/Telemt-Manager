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

# Глобальная переменная для серверных настроек
_S_MAX_CONNECTIONS=""

# ──────────────────────────────────────────────────────────────────────────────
# Публичные точки входа
# ──────────────────────────────────────────────────────────────────────────────
run_install() {
    _show_install_mode_menu
}

run_reinstall() {
    log_info "$MSG_REINSTALL_START"
    stop_telemt_service
    _download_and_place_binary
    _write_systemd_service_file
    reload_systemd
    enable_telemt_service
    start_telemt_service
    log_success "$MSG_REINSTALL_DONE"
    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Подменю режима установки
# ──────────────────────────────────────────────────────────────────────────────
_show_install_mode_menu() {
    while true; do
        clear
        echo -e "${BOLD}${MSG_INSTALL_HEADER}${NC}"
        echo
        echo -e "  ${BOLD}1)${NC} ${MSG_INSTALL_AUTO}"
        echo -e "  ${BOLD}2)${NC} ${MSG_INSTALL_MANUAL}"
        echo
        echo -e "  ${BOLD}Enter)${NC} ${MSG_BACK}"
        echo
        echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
        echo
        echo -n "  ${MSG_YOUR_CHOICE} "
        read -r mode

        case "$mode" in
            1) _install_auto; return ;;
            2) _install_manual; return ;;
            "") return ;;
            *) log_warn "$MSG_INVALID_CHOICE_RETRY"; sleep 1 ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Автоматическая установка
# ──────────────────────────────────────────────────────────────────────────────
_install_auto() {
    log_info "$MSG_AUTO_INSTALL_START"

    local port="$DEFAULT_PORT"
    local domain="$DEFAULT_DOMAIN"
    local username="$DEFAULT_USERNAME"

    if ! _is_port_available "$port"; then
        # shellcheck disable=SC2059
        log_error "$(printf "$MSG_PORT_BUSY" "$port")"
        press_enter_to_continue
        return
    fi

    local reuse_config="new"
    if [ -f "$TELEMT_CONFIG_FILE" ]; then
        reuse_config="reuse"
    fi

    # Параметры первого пользователя (секрет генерируется, остальное по умолчанию)
    _P_SECRET=$(_generate_secret)
    _P_AD_TAG="" _P_MAX_TCP="" _P_MAX_IPS="" _P_EXPIRATION="" _P_DATA_QUOTA=""

    _perform_installation "$port" "$domain" "" "$username" "$reuse_config"
}

# ──────────────────────────────────────────────────────────────────────────────
# Ручная установка
# ──────────────────────────────────────────────────────────────────────────────
_install_manual() {
    log_info "$MSG_MANUAL_INSTALL_START"

    if [ -f "$TELEMT_CONFIG_FILE" ]; then
        echo
        if confirm_action "$MSG_CONFIG_EXISTS_REUSE"; then
            _perform_installation "" "" "" "" "reuse"
            return
        fi
    fi

    echo
    _prompt_port;             local port="$PROMPT_RESULT"
    _prompt_domain;           local domain="$PROMPT_RESULT"
    _prompt_public_host;      local public_host="$PROMPT_RESULT"
    _prompt_max_connections;  _S_MAX_CONNECTIONS="$PROMPT_RESULT"
    _prompt_username;         local username="$PROMPT_RESULT"
    _prompt_secret;           _P_SECRET="$PROMPT_RESULT"

    _perform_installation "$port" "$domain" "$public_host" "$username" "manual"
}

# ──────────────────────────────────────────────────────────────────────────────
# Основная последовательность установки
# ──────────────────────────────────────────────────────────────────────────────
_perform_installation() {
    local port="$1"
    local domain="$2"
    local public_host="$3"
    local username="$4"
    local mode="$5"

    echo
    log_info "$MSG_DOWNLOADING_BINARY"
    _download_and_place_binary || { press_enter_to_continue; return; }

    log_info "$MSG_CREATING_USER"
    _create_system_user

    log_info "$MSG_CREATING_CONFIG"
    _create_config_directory

    if [ "$mode" = "reuse" ]; then
        log_info "$MSG_CONFIG_REUSED"
    else
        _write_config_file "$port" "$domain" "$public_host" "$username" "$_P_SECRET"
    fi

    _set_config_ownership

    log_info "$MSG_CREATING_SERVICE"
    _write_systemd_service_file
    reload_systemd

    log_info "$MSG_STARTING_SERVICE_INSTALL"
    enable_telemt_service
    start_telemt_service

    echo
    log_success "$MSG_INSTALL_DONE"

    if [ "$mode" = "reuse" ]; then
        _show_all_proxy_links
    else
        # shellcheck disable=SC2059
        log_success "$(printf "$MSG_INSTALL_SUMMARY" "$port" "$domain" "$username")"
        if [ "$mode" = "manual" ]; then
            _prompt_and_patch_after_start "$username"
        fi
        _show_proxy_link "$username"
    fi

    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Бинарный файл
# ──────────────────────────────────────────────────────────────────────────────
_download_and_place_binary() {
    _fetch_binary           || return 1
    _move_binary_to_bin     || return 1
    _make_binary_executable || return 1
}

_fetch_binary() {
    local arch libc url
    arch=$(uname -m)
    libc=$(_detect_libc)
    url="https://github.com/telemt/telemt/releases/latest/download/telemt-${arch}-linux-${libc}.tar.gz"

    # shellcheck disable=SC2059
    log_info "$(printf "$MSG_DOWNLOADING_FILE" "telemt-${arch}-linux-${libc}.tar.gz")"
    wget -qO- "$url" | tar -xz -C "$TMP_DIR" || {
        log_error "$MSG_DOWNLOAD_FAILED"
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
        # shellcheck disable=SC2059
        log_info "$(printf "$MSG_USER_EXISTS" "$TELEMT_SYSTEM_USER")"
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
    local public_host="$3"
    local username="$4"
    local secret="$5"

    {
        cat <<EOF
[general]
use_middle_proxy = false

[general.modes]
classic = false
secure = false
tls = true
EOF
        if [ -n "$public_host" ]; then
            cat <<EOF

[general.links]
public_host = "${public_host}"
EOF
        fi
        cat <<EOF

[server]
port = ${port}
EOF
        if [ -n "$_S_MAX_CONNECTIONS" ]; then
            cat <<EOF
max_connections = ${_S_MAX_CONNECTIONS}
EOF
        fi
        cat <<EOF

[server.api]
enabled = true
listen = "${TELEMT_API_LISTEN}"

[censorship]
tls_domain = "${domain}"

[access.users]
${username} = "${secret}"
EOF
    } | sudo tee "$TELEMT_CONFIG_FILE" > /dev/null
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
        # shellcheck disable=SC2059
        echo -n "  $(printf "$MSG_PROMPT_PORT" "$DEFAULT_PORT") "
        read -r PROMPT_RESULT
        PROMPT_RESULT="${PROMPT_RESULT:-$DEFAULT_PORT}"

        if ! _validate_port_number "$PROMPT_RESULT"; then
            log_warn "$MSG_INVALID_PORT"
            continue
        fi

        if ! _is_port_available "$PROMPT_RESULT"; then
            # shellcheck disable=SC2059
            log_warn "$(printf "$MSG_PORT_IN_USE" "$PROMPT_RESULT")"
            continue
        fi

        break
    done
}

_prompt_domain() {
    PROMPT_RESULT=""
    # shellcheck disable=SC2059
    echo -n "  $(printf "$MSG_PROMPT_DOMAIN" "$DEFAULT_DOMAIN") "
    read -r PROMPT_RESULT
    PROMPT_RESULT="${PROMPT_RESULT:-$DEFAULT_DOMAIN}"
}

_prompt_public_host() {
    PROMPT_RESULT=""
    echo -n "  ${MSG_PROMPT_PUBLIC_HOST} "
    read -r PROMPT_RESULT
}

_prompt_max_connections() {
    PROMPT_RESULT=""
    while true; do
        # shellcheck disable=SC2059
        echo -n "  $(printf "$MSG_PROMPT_MAX_CONNECTIONS" "0") "
        read -r PROMPT_RESULT
        PROMPT_RESULT="${PROMPT_RESULT:-0}"

        if _validate_non_negative_integer "$PROMPT_RESULT"; then
            # Значение 0 означает «без ограничений» — не записываем в конфиг
            [ "$PROMPT_RESULT" = "0" ] && PROMPT_RESULT=""
            break
        fi

        log_warn "$MSG_INVALID_MAX_CONNECTIONS"
    done
}

_prompt_username() {
    PROMPT_RESULT=""
    # shellcheck disable=SC2059
    echo -n "  $(printf "$MSG_PROMPT_USERNAME" "$DEFAULT_USERNAME") "
    read -r PROMPT_RESULT
    PROMPT_RESULT="${PROMPT_RESULT:-$DEFAULT_USERNAME}"
}

_prompt_secret() {
    PROMPT_RESULT=""
    while true; do
        echo -n "  ${MSG_SECRET_PROMPT} "
        read -r input

        # Если пустой ввод — генерируем автоматически
        if [[ -z "$input" ]]; then
            PROMPT_RESULT=$(_generate_secret)
            log_success "${MSG_SECRET_GENERATED} ${BOLD}${PROMPT_RESULT}${NC}"
            return
        fi

        # Валидируем введённый секрет
        if _validate_secret "$input"; then
            PROMPT_RESULT="$input"
            return
        fi

        log_warn "$MSG_SECRET_INVALID_FORMAT"
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

_validate_non_negative_integer() {
    local val="$1"
    [[ "$val" =~ ^[0-9]+$ ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# Создание первого пользователя через API после установки
# ──────────────────────────────────────────────────────────────────────────────
_wait_for_api_ready() {
    local max_attempts=30
    for _ in $(seq 1 "$max_attempts"); do
        if curl -s "http://${TELEMT_API_LISTEN}/v1/users" 2>/dev/null \
           | jq -e '.ok == true' &>/dev/null; then
            return 0
        fi
        sleep 1
    done
    return 1
}

_prompt_and_patch_after_start() {
    local username="$1"

    # Ждём готовности API — сервис только что запустился
    if ! _wait_for_api_ready; then
        log_warn "$MSG_USERS_API_ERROR"
        return 1
    fi

    echo
    if ! confirm_action "$MSG_INSTALL_CONFIGURE_USER_PARAMS"; then
        return 0
    fi

    _prompt_install_optional_params

    local body='{}'
    body=$(_build_user_json "$body" "" "$_P_AD_TAG" "$_P_MAX_TCP" \
        "$_P_MAX_IPS" "$_P_EXPIRATION" "$_P_DATA_QUOTA")

    [ "$body" = '{}' ] && return 0

    local response
    response=$(_api_patch "/v1/users/${username}" "$body")

    if ! _api_ok "$response"; then
        log_warn "$MSG_USERS_API_ERROR"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Промпты опциональных параметров пользователя при ручной установке
# (без секрета — он уже запрошен отдельно)
# ──────────────────────────────────────────────────────────────────────────────
_prompt_install_optional_params() {
    echo
    _prompt_optional_param "$MSG_USERS_PARAM_AD_TAG" _validate_hex32 "$MSG_USERS_INVALID_HEX32"
    _P_AD_TAG="$PROMPT_RESULT"

    _prompt_optional_param "$MSG_USERS_PARAM_MAX_TCP" _validate_positive_integer "$MSG_USERS_INVALID_NUMBER"
    _P_MAX_TCP="$PROMPT_RESULT"

    _prompt_optional_param "$MSG_USERS_PARAM_MAX_IPS" _validate_positive_integer "$MSG_USERS_INVALID_NUMBER"
    _P_MAX_IPS="$PROMPT_RESULT"

    _prompt_optional_param "$MSG_USERS_PARAM_EXPIRATION" _validate_rfc3339 "$MSG_USERS_INVALID_RFC3339"
    _P_EXPIRATION="$PROMPT_RESULT"

    _prompt_optional_param "$MSG_USERS_PARAM_DATA_QUOTA" _validate_positive_integer "$MSG_USERS_INVALID_NUMBER"
    _P_DATA_QUOTA="$PROMPT_RESULT"
}

# ──────────────────────────────────────────────────────────────────────────────
# Ссылка прокси
# ──────────────────────────────────────────────────────────────────────────────
_show_proxy_link() {
    local username="$1"

    echo
    log_info "$MSG_FETCHING_LINK"

    local api_json
    api_json=$(_wait_for_api)

    if [ -z "$api_json" ]; then
        log_warn "$MSG_LINK_FAILED"
        log_warn "  curl -s http://${TELEMT_API_LISTEN}/v1/users | jq"
        return
    fi

    local link
    link=$(echo "$api_json" | jq -r --arg u "$username" \
        '.data[] | select(.username == $u) | .links.tls[0] // empty' 2>/dev/null)

    if [ -n "$link" ]; then
        echo
        echo -e "  ${BOLD}${MSG_YOUR_LINK}${NC}"
        echo -e "  ${GREEN}${link}${NC}"
    else
        log_warn "$MSG_LINK_FAILED"
    fi
}

_show_all_proxy_links() {
    echo
    log_info "$MSG_FETCHING_LINK"

    local api_json
    api_json=$(_wait_for_api)

    if [ -z "$api_json" ]; then
        log_warn "$MSG_LINK_FAILED"
        log_warn "  curl -s http://${TELEMT_API_LISTEN}/v1/users | jq"
        return
    fi

    local links
    links=$(echo "$api_json" | jq -r \
        '.data[] | "\(.username) \(.links.tls[0] // empty)"' 2>/dev/null)

    if [ -z "$links" ]; then
        log_warn "$MSG_LINK_FAILED"
        return
    fi

    echo
    while read -r name link; do
        echo -e "  ${BOLD}${name}:${NC}"
        echo -e "  ${GREEN}${link}${NC}"
        echo
    done <<< "$links"
}

_wait_for_api() {
    local api_json
    local max_attempts=30

    for _ in $(seq 1 "$max_attempts"); do
        api_json=$(curl -s "http://${TELEMT_API_LISTEN}/v1/users" 2>/dev/null)
        local first_link
        first_link=$(echo "$api_json" | jq -r '.data[0].links.tls[0] // empty' 2>/dev/null)

        if [ -n "$first_link" ] && ! echo "$first_link" | grep -q 'server=0\.0\.0\.0'; then
            echo "$api_json"
            return
        fi

        sleep 1
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Генераторы
# ──────────────────────────────────────────────────────────────────────────────
_generate_secret() {
    openssl rand -hex 16
}
