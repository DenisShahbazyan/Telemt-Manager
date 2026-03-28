#!/usr/bin/env bash
# Telemt Manager — точка входа
# Запуск: bash <(wget -qO - https://raw.githubusercontent.com/DenisShahbazyan/Telemt-Manager/master/telemt-manager.sh)

set -uo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Константы
# ──────────────────────────────────────────────────────────────────────────────
readonly REPO_BASE_URL="https://raw.githubusercontent.com/DenisShahbazyan/Telemt-Manager/master"
readonly SCRIPT_MODULES=(
    "scripts/common.sh"
    "scripts/install.sh"
    "scripts/uninstall.sh"
    "scripts/update.sh"
    "scripts/edit_config.sh"
    "scripts/users.sh"
)

TMP_DIR=""
LANG_CODE=""

# ──────────────────────────────────────────────────────────────────────────────
# Bootstrap
# ──────────────────────────────────────────────────────────────────────────────
_ensure_wget() {
    command -v wget &>/dev/null && return 0
    echo "wget not found. Installing..."
    sudo apt-get update -qq && sudo apt-get install -y -qq wget || {
        echo "Error: failed to install wget. Install it manually and try again."
        exit 1
    }
}

_create_tmp_dir() {
    TMP_DIR=$(mktemp -d /tmp/telemt-manager-XXXXX)
}

_register_cleanup() {
    trap '_on_exit' EXIT INT TERM
}

_on_exit() {
    [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}

_select_language() {
    echo
    echo "  1) Русский"
    echo "  2) English"
    echo
    echo -n "  Select language / Выберите язык: "
    read -r lang_choice
    case "$lang_choice" in
        1|"") LANG_CODE="ru" ;;
        2)    LANG_CODE="en" ;;
        *)    LANG_CODE="ru" ;;
    esac
}

_download_file() {
    local remote_path="$1"
    local dest="$TMP_DIR/$remote_path"
    mkdir -p "$(dirname "$dest")"
    wget -qO "$dest" "$REPO_BASE_URL/$remote_path" || return 1
}

_load_i18n() {
    _download_file "scripts/i18n/${LANG_CODE}.sh" || {
        echo "Error: failed to download language file."
        exit 1
    }
    # shellcheck source=/dev/null
    source "$TMP_DIR/scripts/i18n/${LANG_CODE}.sh"
}

_load_modules() {
    for module in "${SCRIPT_MODULES[@]}"; do
        _download_file "$module" || {
            echo "$MSG_MODULE_DOWNLOAD_FAILED '$module'"
            echo "$MSG_CHECK_INTERNET"
            exit 1
        }
        # shellcheck source=/dev/null
        source "$TMP_DIR/$module"
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Рендер заголовка
# ──────────────────────────────────────────────────────────────────────────────
_render_header() {
    local installed_ver latest_ver status_label ver_color ver_display

    clear

    installed_ver=$(get_installed_version)
    latest_ver=$(get_latest_version)
    status_label=$(get_service_status_label)

    echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║           TELEMT  MANAGER                ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo

    echo -e "  ${MSG_STATUS_LABEL}  ${status_label}"

    if [ -z "$installed_ver" ]; then
        ver_color="$YELLOW"
        ver_display="$MSG_NOT_INSTALLED"
    elif [ "$installed_ver" = "$latest_ver" ]; then
        ver_color="$GREEN"
        ver_display="$installed_ver"
    else
        ver_color="$RED"
        ver_display="$installed_ver"
    fi

    echo -e "  ${MSG_INSTALLED_VERSION_LABEL} ${ver_color}${ver_display}${NC}"

    if [ -n "$latest_ver" ]; then
        echo -e "  ${MSG_LATEST_VERSION_LABEL}    ${GREEN}${latest_ver}${NC}"
    fi
    echo
    echo -e "${BOLD}──────────────────────────────────────────${NC}"
    echo
}

# ──────────────────────────────────────────────────────────────────────────────
# Рендер меню
# ──────────────────────────────────────────────────────────────────────────────
_render_menu() {
    if is_telemt_installed; then
        echo -e "  ${BOLD}1)${NC} ${MSG_MENU_REINSTALL}"
    else
        echo -e "  ${BOLD}1)${NC} ${MSG_MENU_INSTALL}"
    fi
    echo -e "  ${BOLD}2)${NC} ${MSG_MENU_UPDATE}"
    echo -e "  ${BOLD}3)${NC} ${MSG_MENU_UNINSTALL}"
    echo -e "  ${BOLD}4)${NC} ${MSG_MENU_USERS}"
    echo -e "  ${BOLD}5)${NC} ${MSG_MENU_EDIT_CONFIG}"
    echo
    echo -e "  ${BOLD}Enter)${NC} ${MSG_MENU_EXIT}"
    echo
    echo -e "${BOLD}──────────────────────────────────────────${NC}"
    echo
}

# ──────────────────────────────────────────────────────────────────────────────
# Обработка выбора
# ──────────────────────────────────────────────────────────────────────────────
_handle_choice() {
    local choice="$1"
    case "$choice" in
        1)
            if is_telemt_installed; then
                run_reinstall
            else
                run_install
            fi
            ;;
        2) run_update ;;
        3) run_uninstall ;;
        4) run_users ;;
        5) run_edit_config ;;
        "") exit 0 ;;
        *)
            echo -e "${YELLOW}  ${MSG_INVALID_CHOICE}: '$choice'${NC}"
            sleep 1
            ;;
    esac
}

_menu_loop() {
    while true; do
        _render_header
        _render_menu
        echo -n "  ${MSG_YOUR_CHOICE} "
        read -r choice
        _handle_choice "$choice"
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Точка входа
# ──────────────────────────────────────────────────────────────────────────────
main() {
    _ensure_wget
    _create_tmp_dir
    _register_cleanup
    _select_language
    _load_i18n
    _load_modules
    init_logging
    check_and_install_dependencies
    _menu_loop
}

main
