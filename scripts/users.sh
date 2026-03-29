#!/usr/bin/env bash
# Управление пользователями Telemt через API

# Количество пользователей на странице
USERS_PAGE_SIZE=5

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
    local current_page=1

    while true; do
        clear
        echo -e "${BOLD}${MSG_USERS_HEADER}${NC}"
        echo

        # _list_users_display устанавливает _USERS_TOTAL_PAGES
        _list_users_display "$current_page"

        echo
        echo -e "  ${BOLD}1)${NC} ${MSG_USERS_ADD}"
        echo -e "  ${BOLD}2)${NC} ${MSG_USERS_EDIT}"
        echo -e "  ${BOLD}3)${NC} ${MSG_USERS_REMOVE}"

        if [ "${_USERS_TOTAL_PAGES:-1}" -gt 1 ]; then
            echo
            if [ "$current_page" -lt "$_USERS_TOTAL_PAGES" ]; then
                echo -e "  ${BOLD}n)${NC} ${MSG_USERS_PAGE_NEXT}"
            fi
            if [ "$current_page" -gt 1 ]; then
                echo -e "  ${BOLD}p)${NC} ${MSG_USERS_PAGE_PREV}"
            fi
        fi

        echo
        echo -e "  ${BOLD}Enter)${NC} ${MSG_BACK}"
        echo
        echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
        echo
        echo -n "  ${MSG_YOUR_CHOICE} "
        read -r choice

        case "$choice" in
            1) _add_user; current_page=1 ;;
            2) _edit_user "$current_page" ;;
            3) _remove_user "$current_page"; current_page=1 ;;
            n|N)
                if [ "$current_page" -lt "${_USERS_TOTAL_PAGES:-1}" ]; then
                    current_page=$((current_page + 1))
                fi
                ;;
            p|P)
                if [ "$current_page" -gt 1 ]; then
                    current_page=$((current_page - 1))
                fi
                ;;
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
# Получение секрета пользователя из TOML-конфига
# ──────────────────────────────────────────────────────────────────────────────
_get_secret_from_config() {
    local username="$1"
    sudo sed -n '/^\[access\.users\]/,/^\[/{/^'"${username}"'[[:space:]]*=/{s/.*=[[:space:]]*"\([^"]*\)".*/\1/;p;q;}}' \
        "$TELEMT_CONFIG_FILE" 2>/dev/null
}

# ──────────────────────────────────────────────────────────────────────────────
# Список пользователей
# ──────────────────────────────────────────────────────────────────────────────
_list_users_display() {
    local page="${1:-1}"
    _USERS_TOTAL_PAGES=1

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

    # Вычисляем пагинацию
    _USERS_TOTAL_PAGES=$(( (count + USERS_PAGE_SIZE - 1) / USERS_PAGE_SIZE ))
    if [ "$page" -gt "$_USERS_TOTAL_PAGES" ]; then
        page="$_USERS_TOTAL_PAGES"
    fi

    local offset=$(( (page - 1) * USERS_PAGE_SIZE ))

    echo -e "  ${BOLD}${MSG_USERS_LIST_HEADER}${NC}"
    if [ "$_USERS_TOTAL_PAGES" -gt 1 ]; then
        # shellcheck disable=SC2059
        echo -e "  $(printf "$MSG_USERS_PAGE_INFO" "$page" "$_USERS_TOTAL_PAGES" "$count")"
    fi
    echo

    local users_json
    users_json=$(echo "$response" | jq -c ".data[$offset:$((offset + USERS_PAGE_SIZE))][]")

    while IFS= read -r user_obj; do
        local name link ad_tag max_tcp max_ips expiration data_quota
        name=$(echo "$user_obj" | jq -r '.username')
        link=$(echo "$user_obj" | jq -r '.links.tls[0] // empty')
        ad_tag=$(echo "$user_obj" | jq -r '.user_ad_tag // empty')
        max_tcp=$(echo "$user_obj" | jq -r '.max_tcp_conns // empty')
        max_ips=$(echo "$user_obj" | jq -r '.max_unique_ips // empty')
        expiration=$(echo "$user_obj" | jq -r '.expiration_rfc3339 // empty')
        data_quota=$(echo "$user_obj" | jq -r '.data_quota_bytes // empty')

        local secret
        secret=$(_get_secret_from_config "$name")

        echo -e "  ${BOLD}•${NC} ${name}"

        if [ -n "$link" ]; then
            echo -e "    ${MSG_USERS_LABEL_LINK} ${GREEN}${link}${NC}"
        fi

        echo -e "    ${MSG_USERS_SECRET_LABEL} ${CYAN}${secret:-${MSG_USERS_LABEL_NOT_SET}}${NC}"

        echo -e "    ${MSG_USERS_LABEL_AD_TAG} ${CYAN}${ad_tag:-${MSG_USERS_LABEL_NOT_SET}}${NC}"

        local tcp_display="${MSG_USERS_LABEL_UNLIMITED}"
        if [ -n "$max_tcp" ] && [ "$max_tcp" != "0" ]; then
            tcp_display="$max_tcp"
        fi
        echo -e "    ${MSG_USERS_LABEL_MAX_TCP} ${tcp_display}"

        local ips_display="${MSG_USERS_LABEL_UNLIMITED}"
        if [ -n "$max_ips" ] && [ "$max_ips" != "0" ]; then
            ips_display="$max_ips"
        fi
        echo -e "    ${MSG_USERS_LABEL_MAX_IPS} ${ips_display}"

        if [ -n "$expiration" ]; then
            echo -e "    ${MSG_USERS_LABEL_EXPIRATION} ${expiration}"
        else
            echo -e "    ${MSG_USERS_LABEL_EXPIRATION} ${MSG_USERS_LABEL_PERMANENT}"
        fi

        if [ -n "$data_quota" ] && [ "$data_quota" != "0" ]; then
            echo -e "    ${MSG_USERS_LABEL_DATA_QUOTA} $(_format_bytes "$data_quota")"
        else
            echo -e "    ${MSG_USERS_LABEL_DATA_QUOTA} ${MSG_USERS_LABEL_UNLIMITED}"
        fi

        echo
    done <<< "$users_json"
}

# ──────────────────────────────────────────────────────────────────────────────
# Форматирование байтов в человекочитаемый вид
# ──────────────────────────────────────────────────────────────────────────────
_format_bytes() {
    local bytes="$1"

    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(( bytes / 1073741824 )) GiB (${bytes})"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(( bytes / 1048576 )) MiB (${bytes})"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(( bytes / 1024 )) KiB (${bytes})"
    else
        echo "${bytes} B"
    fi
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
    local page="${1:-1}"

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

    # Вычисляем срез для текущей страницы
    local offset=$(( (page - 1) * USERS_PAGE_SIZE ))
    local names=()
    local i=1
    echo
    while read -r name; do
        names+=("$name")
        echo -e "  ${BOLD}${i})${NC} ${name}"
        i=$((i + 1))
    done < <(echo "$response" | jq -r ".data[$offset:$((offset + USERS_PAGE_SIZE))][].username")

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

        # Получаем текущие данные пользователя
        local user_data cur_ad_tag cur_max_tcp cur_max_ips cur_exp cur_quota cur_secret
        user_data=$(_api_get "/v1/users/${username}")
        cur_ad_tag=$(echo "$user_data" | jq -r '.data.user_ad_tag // empty' 2>/dev/null)
        cur_max_tcp=$(echo "$user_data" | jq -r '.data.max_tcp_conns // empty' 2>/dev/null)
        cur_max_ips=$(echo "$user_data" | jq -r '.data.max_unique_ips // empty' 2>/dev/null)
        cur_exp=$(echo "$user_data" | jq -r '.data.expiration_rfc3339 // empty' 2>/dev/null)
        cur_quota=$(echo "$user_data" | jq -r '.data.data_quota_bytes // empty' 2>/dev/null)
        cur_secret=$(_get_secret_from_config "$username")

        local val_tcp val_ips val_exp val_quota

        if [ -n "$cur_max_tcp" ] && [ "$cur_max_tcp" != "0" ]; then
            val_tcp="$cur_max_tcp"
        else
            val_tcp="$MSG_USERS_LABEL_UNLIMITED"
        fi

        if [ -n "$cur_max_ips" ] && [ "$cur_max_ips" != "0" ]; then
            val_ips="$cur_max_ips"
        else
            val_ips="$MSG_USERS_LABEL_UNLIMITED"
        fi

        if [ -n "$cur_exp" ]; then
            val_exp="$cur_exp"
        else
            val_exp="$MSG_USERS_LABEL_PERMANENT"
        fi

        if [ -n "$cur_quota" ] && [ "$cur_quota" != "0" ]; then
            val_quota=$(_format_bytes "$cur_quota")
        else
            val_quota="$MSG_USERS_LABEL_UNLIMITED"
        fi

        echo -e "  ${BOLD}1)${NC} ${MSG_USERS_EDIT_SECRET} ${CYAN}${cur_secret:-${MSG_USERS_LABEL_NOT_SET}}${NC}"
        echo -e "  ${BOLD}2)${NC} ${MSG_USERS_EDIT_AD_TAG} ${CYAN}${cur_ad_tag:-${MSG_USERS_LABEL_NOT_SET}}${NC}"
        echo -e "  ${BOLD}3)${NC} ${MSG_USERS_EDIT_MAX_TCP} ${CYAN}${val_tcp}${NC}"
        echo -e "  ${BOLD}4)${NC} ${MSG_USERS_EDIT_MAX_IPS} ${CYAN}${val_ips}${NC}"
        echo -e "  ${BOLD}5)${NC} ${MSG_USERS_EDIT_EXPIRATION} ${CYAN}${val_exp}${NC}"
        echo -e "  ${BOLD}6)${NC} ${MSG_USERS_EDIT_DATA_QUOTA} ${CYAN}${val_quota}${NC}"

        echo
        echo -e "  ${BOLD}Enter)${NC} ${MSG_BACK}"
        echo
        echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
        echo
        echo -n "  ${MSG_USERS_EDIT_FIELD} "
        read -r choice

        case "$choice" in
            1) _edit_secret "$username" ;;
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

_edit_secret() {
    local username="$1"

    echo
    echo -e "  ${MSG_SECRET_HEADER}"
    echo -e "    ${BOLD}1)${NC} ${MSG_SECRET_AUTO}"
    echo -e "    ${BOLD}2)${NC} ${MSG_SECRET_MANUAL}"
    echo
    echo -e "    ${BOLD}Enter)${NC} ${MSG_BACK}"
    echo -n "  ${MSG_SECRET_CHOICE} "
    read -r choice
    choice="${choice:-}"

    local secret=""
    case "$choice" in
        1)
            secret=$(_generate_secret)
            ;;
        2)
            while true; do
                echo -n "  ${MSG_SECRET_ENTER} "
                read -r secret

                if [ -z "$secret" ]; then
                    return
                fi

                if _validate_hex32 "$secret"; then
                    break
                fi

                log_warn "$MSG_USERS_INVALID_HEX32"
            done
            ;;
        *)
            return
            ;;
    esac

    local body
    body=$(jq -n --arg v "$secret" '{secret: $v}')

    local response
    response=$(_api_patch "/v1/users/${username}" "$body")

    if _api_ok "$response"; then
        # shellcheck disable=SC2059
        log_success "$(printf "$MSG_USERS_UPDATED" "$username")"
        echo -e "  ${BOLD}${MSG_USERS_SECRET_LABEL}${NC} ${CYAN}${secret}${NC}"
    else
        log_error "$MSG_USERS_API_ERROR"
    fi

    press_enter_to_continue
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
    local page="${1:-1}"

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

    # Вычисляем срез для текущей страницы
    local offset=$(( (page - 1) * USERS_PAGE_SIZE ))
    local names=()
    local i=1
    echo
    while read -r name; do
        names+=("$name")
        echo -e "  ${BOLD}${i})${NC} ${name}"
        i=$((i + 1))
    done < <(echo "$response" | jq -r ".data[$offset:$((offset + USERS_PAGE_SIZE))][].username")

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
