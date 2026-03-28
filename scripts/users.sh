#!/usr/bin/env bash
# Управление пользователями Telemt

# ──────────────────────────────────────────────────────────────────────────────
# Публичная точка входа
# ──────────────────────────────────────────────────────────────────────────────
run_users() {
    if [ ! -f "$TELEMT_CONFIG_FILE" ]; then
        log_warn "$MSG_CONFIG_NOT_FOUND"
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
# Список пользователей
# ──────────────────────────────────────────────────────────────────────────────
_list_users_display() {
    local users
    users=$(_parse_users)

    if [ -z "$users" ]; then
        echo -e "  ${YELLOW}${MSG_USERS_EMPTY}${NC}"
        return
    fi

    echo -e "  ${BOLD}${MSG_USERS_LIST_HEADER}${NC}"
    echo

    local i=1
    while IFS='=' read -r name secret; do
        name=$(echo "$name" | xargs)
        secret=$(echo "$secret" | xargs | tr -d '"')
        echo -e "  ${BOLD}${i})${NC} ${name}  ${CYAN}${secret}${NC}"
        i=$((i + 1))
    done <<< "$users"
}

_parse_users() {
    sudo sed -n '/^\[access\.users\]/,/^\[/{/^\[/d; /^#/d; /^$/d; p}' "$TELEMT_CONFIG_FILE"
}

_get_user_count() {
    local users
    users=$(_parse_users)
    if [ -z "$users" ]; then
        echo 0
    else
        echo "$users" | wc -l | xargs
    fi
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

    if _user_exists "$username"; then
        # shellcheck disable=SC2059
        log_warn "$(printf "$MSG_USERS_ALREADY_EXISTS" "$username")"
        press_enter_to_continue
        return
    fi

    _prompt_user_secret
    local secret="$PROMPT_RESULT"

    sudo sed -i "/^\[access\.users\]/a ${username} = \"${secret}\"" "$TELEMT_CONFIG_FILE"
    _set_config_ownership

    # shellcheck disable=SC2059
    log_success "$(printf "$MSG_USERS_ADDED" "$username")"

    restart_telemt_service
    _show_user_link "$username"
    press_enter_to_continue
}

_user_exists() {
    local username="$1"
    _parse_users | grep -q "^${username}[[:space:]]*="
}

_prompt_user_secret() {
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
                _prompt_user_manual_secret
                return
                ;;
            *)
                log_warn "$MSG_SECRET_INVALID_CHOICE"
                ;;
        esac
    done
}

_prompt_user_manual_secret() {
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
# Удаление пользователя
# ──────────────────────────────────────────────────────────────────────────────
_remove_user() {
    local users
    users=$(_parse_users)

    if [ -z "$users" ]; then
        log_warn "$MSG_USERS_EMPTY"
        press_enter_to_continue
        return
    fi

    local count
    count=$(_get_user_count)

    if [ "$count" -le 1 ]; then
        log_warn "$MSG_USERS_CANT_REMOVE_LAST"
        press_enter_to_continue
        return
    fi

    echo
    local names=()
    local i=1
    while IFS='=' read -r name _; do
        name=$(echo "$name" | xargs)
        names+=("$name")
        echo -e "  ${BOLD}${i})${NC} ${name}"
        i=$((i + 1))
    done <<< "$users"

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

    sudo sed -i "/^${target}[[:space:]]*=/d" "$TELEMT_CONFIG_FILE"

    # shellcheck disable=SC2059
    log_success "$(printf "$MSG_USERS_REMOVED" "$target")"

    restart_telemt_service
    press_enter_to_continue
}

# ──────────────────────────────────────────────────────────────────────────────
# Ссылка для пользователя
# ──────────────────────────────────────────────────────────────────────────────
_show_user_link() {
    local username="$1"

    echo
    log_info "$MSG_FETCHING_LINK"

    local link=""
    local max_attempts=15

    for _ in $(seq 1 "$max_attempts"); do
        link=$(
            curl -s "http://${TELEMT_API_LISTEN}/v1/users" 2>/dev/null \
                | jq -r --arg u "$username" \
                    '.data[] | select(.name == $u) | .links.tls[0] // empty' 2>/dev/null
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
