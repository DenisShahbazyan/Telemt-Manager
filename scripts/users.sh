#!/usr/bin/env bash
# Управление пользователями Telemt через API

# ──────────────────────────────────────────────────────────────────────────────
# Публичная точка входа
# ──────────────────────────────────────────────────────────────────────────────
run_users() {
    if ! is_telemt_installed; then
        log_warn "$MSG_NOT_INSTALLED_WARN"
        press_enter_to_continue
        return
    fi

    if [ "$(get_service_status)" != "active" ]; then
        log_warn "$MSG_USERS_SERVICE_NOT_RUNNING"
        press_enter_to_continue
        return
    fi

    _show_users_menu
}

# ──────────────────────────────────────────────────────────────────────────────
# Подменю управления пользователями
# ──────────────────────────────────────────────────────────────────────────────
_show_users_menu() {
    while true; do
        clear
        echo -e "${BOLD}${MSG_USERS_HEADER}${NC}"
        echo

        _list_users_display

        echo
        echo -e "  ${BOLD}1)${NC} ${MSG_USERS_ADD}"
        echo -e "  ${BOLD}2)${NC} ${MSG_USERS_REMOVE}"
        echo
        echo -e "  ${BOLD}Enter)${NC} ${MSG_BACK}"
        echo
        echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
        echo
        echo -n "  ${MSG_YOUR_CHOICE} "
        read -r choice

        case "$choice" in
            1) _add_user ;;
            2) _remove_user ;;
            "") return ;;
            *) log_warn "$MSG_INVALID_CHOICE_RETRY"; sleep 1 ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# API-хелперы
# ──────────────────────────────────────────────────────────────────────────────
_api_get() {
    local path="$1"
    curl -s "http://${TELEMT_API_LISTEN}${path}" 2>/dev/null
}

_api_post() {
    local path="$1"
    local body="$2"
    curl -s -X POST "http://${TELEMT_API_LISTEN}${path}" \
        -H "Content-Type: application/json" \
        -d "$body" 2>/dev/null
}

_api_delete() {
    local path="$1"
    curl -s -X DELETE "http://${TELEMT_API_LISTEN}${path}" 2>/dev/null
}

_api_ok() {
    local response="$1"
    [ -n "$response" ] && echo "$response" | jq -e '.ok == true' &>/dev/null
}

# ──────────────────────────────────────────────────────────────────────────────
# Список пользователей
# ──────────────────────────────────────────────────────────────────────────────
_list_users_display() {
    local response
    response=$(_api_get "/v1/users")

    if ! _api_ok "$response"; then
        echo -e "  ${YELLOW}${MSG_USERS_API_ERROR}${NC}"
        return
    fi

    local count
    count=$(echo "$response" | jq '.data | length')

    if [ "$count" -eq 0 ]; then
        echo -e "  ${YELLOW}${MSG_USERS_EMPTY}${NC}"
        return
    fi

    echo -e "  ${BOLD}${MSG_USERS_LIST_HEADER}${NC}"
    echo

    echo "$response" | jq -r '.data[] | .username' | while read -r name; do
        local link
        link=$(echo "$response" | jq -r --arg u "$name" \
            '.data[] | select(.username == $u) | .links.tls[0] // empty')
        echo -e "  ${BOLD}•${NC} ${name}"
        if [ -n "$link" ]; then
            echo -e "    ${GREEN}${link}${NC}"
        fi
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Добавление пользователя
# ──────────────────────────────────────────────────────────────────────────────
_add_user() {
    echo
    echo -n "  ${MSG_USERS_ENTER_NAME} "
    read -r username

    if [ -z "$username" ]; then
        log_warn "$MSG_USERS_NAME_EMPTY"
        press_enter_to_continue
        return
    fi

    local body="{\"username\": \"${username}\"}"

    local response
    response=$(_api_post "/v1/users" "$body")

    if ! _api_ok "$response"; then
        local http_hint
        http_hint=$(echo "$response" | jq -r '.data // empty' 2>/dev/null)
        if echo "$response" | jq -e 'select(.ok == false)' &>/dev/null; then
            # shellcheck disable=SC2059
            log_error "$(printf "$MSG_USERS_ALREADY_EXISTS" "$username")"
        else
            log_error "$MSG_USERS_API_ERROR"
        fi
        press_enter_to_continue
        return
    fi

    local secret
    secret=$(echo "$response" | jq -r '.data.secret // empty')

    # shellcheck disable=SC2059
    log_success "$(printf "$MSG_USERS_ADDED" "$username")"

    if [ -n "$secret" ]; then
        echo -e "  ${BOLD}${MSG_USERS_SECRET_LABEL}${NC} ${CYAN}${secret}${NC}"
    fi

    _show_user_link_from_response "$response" "$username"
    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Удаление пользователя
# ──────────────────────────────────────────────────────────────────────────────
_remove_user() {
    local response
    response=$(_api_get "/v1/users")

    if ! _api_ok "$response"; then
        log_error "$MSG_USERS_API_ERROR"
        press_enter_to_continue
        return
    fi

    local count
    count=$(echo "$response" | jq '.data | length')

    if [ "$count" -eq 0 ]; then
        log_warn "$MSG_USERS_EMPTY"
        press_enter_to_continue
        return
    fi

    if [ "$count" -le 1 ]; then
        log_warn "$MSG_USERS_CANT_REMOVE_LAST"
        press_enter_to_continue
        return
    fi

    echo
    local names=()
    local i=1
    while read -r name; do
        names+=("$name")
        echo -e "  ${BOLD}${i})${NC} ${name}"
        i=$((i + 1))
    done < <(echo "$response" | jq -r '.data[].username')

    echo
    echo -n "  ${MSG_USERS_SELECT_REMOVE} "
    read -r num

    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#names[@]}" ]; then
        log_warn "$MSG_INVALID_CHOICE_RETRY"
        press_enter_to_continue
        return
    fi

    local target="${names[$((num - 1))]}"

    # shellcheck disable=SC2059
    if ! confirm_action "$(printf "$MSG_USERS_CONFIRM_REMOVE" "$target")"; then
        log_info "$MSG_USERS_REMOVE_CANCELLED"
        press_enter_to_continue
        return
    fi

    local del_response
    del_response=$(_api_delete "/v1/users/${target}")

    if _api_ok "$del_response"; then
        # shellcheck disable=SC2059
        log_success "$(printf "$MSG_USERS_REMOVED" "$target")"
    else
        log_error "$MSG_USERS_API_ERROR"
    fi

    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Ссылки пользователей
# ──────────────────────────────────────────────────────────────────────────────
_fetch_all_user_links() {
    _api_get "/v1/users"
}

_show_user_link_from_response() {
    local response="$1"
    local username="$2"

    local link
    link=$(echo "$response" | jq -r --arg u "$username" \
        '.data.user.links.tls[0] // empty' 2>/dev/null)

    if [ -n "$link" ] && ! echo "$link" | grep -q 'server=0\.0\.0\.0'; then
        echo
        echo -e "  ${BOLD}${MSG_YOUR_LINK}${NC}"
        echo -e "  ${GREEN}${link}${NC}"
        return
    fi

    # Если в ответе POST нет ссылки, запросим через GET с ретраями
    _show_user_link "$username"
}

_show_user_link() {
    local username="$1"

    echo
    log_info "$MSG_FETCHING_LINK"

    local link=""
    local max_attempts=15

    for _ in $(seq 1 "$max_attempts"); do
        link=$(
            _api_get "/v1/users/${username}" \
                | jq -r '.data.links.tls[0] // empty' 2>/dev/null
        )

        if [ -n "$link" ] && ! echo "$link" | grep -q 'server=0\.0\.0\.0'; then
            break
        fi

        sleep 1
    done

    if [ -n "$link" ]; then
        echo
        echo -e "  ${BOLD}${MSG_YOUR_LINK}${NC}"
        echo -e "  ${GREEN}${link}${NC}"
    else
        log_warn "$MSG_LINK_FAILED"
    fi
}
