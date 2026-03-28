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
    local secret
    secret=$(_generate_secret)

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

    _perform_installation "$port" "$domain" "$username" "$secret" "$reuse_config"
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
    _prompt_port;     local port="$PROMPT_RESULT"
    _prompt_domain;   local domain="$PROMPT_RESULT"
    _prompt_username; local username="$PROMPT_RESULT"
    _prompt_secret;   local secret="$PROMPT_RESULT"

    _perform_installation "$port" "$domain" "$username" "$secret" "new"
}

# ──────────────────────────────────────────────────────────────────────────────
# Основная последовательность установки
# ──────────────────────────────────────────────────────────────────────────────
_perform_installation() {
    local port="$1"
    local domain="$2"
    local username="$3"
    local secret="$4"
    local mode="$5"

    echo
    log_info "$MSG_DOWNLOADING_BINARY"
    _download_and_place_binary || return

    log_info "$MSG_CREATING_USER"
    _create_system_user

    log_info "$MSG_CREATING_CONFIG"
    _create_config_directory

    if [ "$mode" = "reuse" ]; then
        log_info "$MSG_CONFIG_REUSED"
    else
        _write_config_file "$port" "$domain" "$username" "$secret"
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
        _show_proxy_link "$username"
    fi

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

# format: "username" = "32_hex_chars_secret"
[access.users]
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
        echo
        echo -e "  ${MSG_SECRET_HEADER}"
        echo -e "    ${BOLD}1)${NC} ${MSG_SECRET_AUTO}"
        echo -e "    ${BOLD}2)${NC} ${MSG_SECRET_MANUAL}"
        echo -n "  ${MSG_SECRET_CHOICE} "
        read -r choice
        choice="${choice:-1}"

        case "$choice" in
            1)
                PROMPT_RESULT=$(_generate_secret)
                log_success "${MSG_SECRET_GENERATED} ${BOLD}${PROMPT_RESULT}${NC}"
                return
                ;;
            2)
                _prompt_manual_secret
                return
                ;;
            *)
                log_warn "$MSG_SECRET_INVALID_CHOICE"
                ;;
        esac
    done
}

_prompt_manual_secret() {
    while true; do
        echo -n "  ${MSG_SECRET_ENTER} "
        read -r PROMPT_RESULT

        if _validate_secret "$PROMPT_RESULT"; then
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
