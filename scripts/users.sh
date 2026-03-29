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
        echo -e "  ${BOLD}2)${NC} ${MSG_USERS_EDIT}"
        echo -e "  ${BOLD}3)${NC} ${MSG_USERS_REMOVE}"
        echo
        echo -e "  ${BOLD}Enter)${NC} ${MSG_BACK}"
        echo
        echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
        echo
        echo -n "  ${MSG_YOUR_CHOICE} "
        read -r choice

        case "$choice" in
            1) _add_user ;;
            2) _edit_user ;;
            3) _remove_user ;;
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

_api_patch() {
    local path="$1"
    local body="$2"
    curl -s -X PATCH "http://${TELEMT_API_LISTEN}${path}" \
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
# Валидаторы параметров пользователя
# ──────────────────────────────────────────────────────────────────────────────
_validate_username() {
    local name="$1"
    [[ "$name" =~ ^[A-Za-z0-9_.'-']{1,64}$ ]]
}

_validate_hex32() {
    local value="$1"
    [[ "$value" =~ ^[0-9a-f]{32}$ ]]
}

_validate_positive_integer() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]
}

_validate_rfc3339() {
    local value="$1"
    [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$ ]]
}

# ──────────────────────────────────────────────────────────────────────────────
# Промпт опционального параметра с валидацией
# Аргументы: label, validator_func, error_msg
# Результат в PROMPT_RESULT (пусто = пропущен)
# ──────────────────────────────────────────────────────────────────────────────
_prompt_optional_param() {
    local label="$1"
    local validator="$2"
    local error_msg="$3"

    PROMPT_RESULT=""
    while true; do
        echo -n "  ${label} ${MSG_USERS_SKIP_HINT} "
        read -r PROMPT_RESULT

        if [ -z "$PROMPT_RESULT" ]; then
            return
        fi

        if "$validator" "$PROMPT_RESULT"; then
            return
        fi

        log_warn "$error_msg"
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Сборка JSON body с опциональными параметрами
# ──────────────────────────────────────────────────────────────────────────────
_build_user_json() {
    local body="$1"
    local secret="$2"
    local ad_tag="$3"
    local max_tcp="$4"
    local max_ips="$5"
    local expiration="$6"
    local data_quota="$7"

    if [ -n "$secret" ]; then
        body=$(echo "$body" | jq --arg v "$secret" '. + {secret: $v}')
    fi
    if [ -n "$ad_tag" ]; then
        body=$(echo "$body" | jq --arg v "$ad_tag" '. + {user_ad_tag: $v}')
    fi
    if [ -n "$max_tcp" ]; then
        body=$(echo "$body" | jq --argjson v "$max_tcp" '. + {max_tcp_conns: $v}')
    fi
    if [ -n "$max_ips" ]; then
        body=$(echo "$body" | jq --argjson v "$max_ips" '. + {max_unique_ips: $v}')
    fi
    if [ -n "$expiration" ]; then
        body=$(echo "$body" | jq --arg v "$expiration" '. + {expiration_rfc3339: $v}')
    fi
    if [ -n "$data_quota" ]; then
        body=$(echo "$body" | jq --argjson v "$data_quota" '. + {data_quota_bytes: $v}')
    fi

    echo "$body"
}

# ──────────────────────────────────────────────────────────────────────────────
# Промпты всех опциональных параметров
# Результаты в переменных: _P_SECRET, _P_AD_TAG, _P_MAX_TCP, _P_MAX_IPS,
#                           _P_EXPIRATION, _P_DATA_QUOTA
# ──────────────────────────────────────────────────────────────────────────────
_prompt_all_optional_params() {
    _P_SECRET=""
    _P_AD_TAG=""
    _P_MAX_TCP=""
    _P_MAX_IPS=""
    _P_EXPIRATION=""
    _P_DATA_QUOTA=""

    echo

    _prompt_optional_param "$MSG_USERS_PARAM_SECRET" _validate_hex32 "$MSG_USERS_INVALID_HEX32"
    _P_SECRET="$PROMPT_RESULT"

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

    if ! _validate_username "$username"; then
        log_warn "$MSG_USERS_NAME_INVALID"
        press_enter_to_continue
        return
    fi

    local body
    body=$(jq -n --arg u "$username" '{username: $u}')

    if confirm_action "$MSG_USERS_CONFIGURE_PARAMS"; then
        _prompt_all_optional_params
        body=$(_build_user_json "$body" \
            "$_P_SECRET" "$_P_AD_TAG" "$_P_MAX_TCP" \
            "$_P_MAX_IPS" "$_P_EXPIRATION" "$_P_DATA_QUOTA")
    fi

    echo
    local response
    response=$(_api_post "/v1/users" "$body")

    if ! _api_ok "$response"; then
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
# Редактирование пользователя
# ──────────────────────────────────────────────────────────────────────────────
_edit_user() {
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

    echo
    local names=()
    local i=1
    while read -r name; do
        names+=("$name")
        echo -e "  ${BOLD}${i})${NC} ${name}"
        i=$((i + 1))
    done < <(echo "$response" | jq -r '.data[].username')

    echo
    echo -n "  ${MSG_USERS_SELECT_EDIT} "
    read -r num

    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#names[@]}" ]; then
        log_warn "$MSG_INVALID_CHOICE_RETRY"
        press_enter_to_continue
        return
    fi

    local target="${names[$((num - 1))]}"

    _show_edit_params_menu "$target"
}

_show_edit_params_menu() {
    local username="$1"

    while true; do
        clear
        # shellcheck disable=SC2059
        echo -e "${BOLD}$(printf "$MSG_USERS_EDIT_HEADER" "$username")${NC}"
        echo
        echo -e "  ${BOLD}1)${NC} ${MSG_USERS_PARAM_SECRET}"
        echo -e "  ${BOLD}2)${NC} ${MSG_USERS_PARAM_AD_TAG}"
        echo -e "  ${BOLD}3)${NC} ${MSG_USERS_PARAM_MAX_TCP}"
        echo -e "  ${BOLD}4)${NC} ${MSG_USERS_PARAM_MAX_IPS}"
        echo -e "  ${BOLD}5)${NC} ${MSG_USERS_PARAM_EXPIRATION}"
        echo -e "  ${BOLD}6)${NC} ${MSG_USERS_PARAM_DATA_QUOTA}"
        echo
        echo -e "  ${BOLD}Enter)${NC} ${MSG_BACK}"
        echo
        echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
        echo
        echo -n "  ${MSG_USERS_EDIT_FIELD} "
        read -r choice

        case "$choice" in
            1) _edit_single_param "$username" "$MSG_USERS_PARAM_SECRET" \
                   _validate_hex32 "$MSG_USERS_INVALID_HEX32" "secret" "string" ;;
            2) _edit_single_param "$username" "$MSG_USERS_PARAM_AD_TAG" \
                   _validate_hex32 "$MSG_USERS_INVALID_HEX32" "user_ad_tag" "string" ;;
            3) _edit_single_param "$username" "$MSG_USERS_PARAM_MAX_TCP" \
                   _validate_positive_integer "$MSG_USERS_INVALID_NUMBER" "max_tcp_conns" "number" ;;
            4) _edit_single_param "$username" "$MSG_USERS_PARAM_MAX_IPS" \
                   _validate_positive_integer "$MSG_USERS_INVALID_NUMBER" "max_unique_ips" "number" ;;
            5) _edit_single_param "$username" "$MSG_USERS_PARAM_EXPIRATION" \
                   _validate_rfc3339 "$MSG_USERS_INVALID_RFC3339" "expiration_rfc3339" "string" ;;
            6) _edit_single_param "$username" "$MSG_USERS_PARAM_DATA_QUOTA" \
                   _validate_positive_integer "$MSG_USERS_INVALID_NUMBER" "data_quota_bytes" "number" ;;
            "") return ;;
            *) log_warn "$MSG_INVALID_CHOICE_RETRY"; sleep 1 ;;
        esac
    done
}

_edit_single_param() {
    local username="$1"
    local label="$2"
    local validator="$3"
    local error_msg="$4"
    local json_key="$5"
    local value_type="$6"

    echo
    local value=""
    while true; do
        echo -n "  ${label} "
        read -r value

        if [ -z "$value" ]; then
            return
        fi

        if "$validator" "$value"; then
            break
        fi

        log_warn "$error_msg"
    done

    local body
    if [ "$value_type" = "number" ]; then
        body=$(jq -n --arg k "$json_key" --argjson v "$value" '{($k): $v}')
    else
        body=$(jq -n --arg k "$json_key" --arg v "$value" '{($k): $v}')
    fi

    local response
    response=$(_api_patch "/v1/users/${username}" "$body")

    if _api_ok "$response"; then
        # shellcheck disable=SC2059
        log_success "$(printf "$MSG_USERS_UPDATED" "$username")"
    else
        log_error "$MSG_USERS_API_ERROR"
    fi

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
