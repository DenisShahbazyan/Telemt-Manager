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
)

TMP_DIR=""

# ──────────────────────────────────────────────────────────────────────────────
# Bootstrap
# ──────────────────────────────────────────────────────────────────────────────
_ensure_wget() {
    command -v wget &>/dev/null && return 0
    echo "wget не найден. Установка..."
    sudo apt-get update -qq && sudo apt-get install -y -qq wget || {
        echo "Ошибка: не удалось установить wget. Установите вручную и повторите."
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

_download_module() {
    local module="$1"
    local dest="$TMP_DIR/$module"
    mkdir -p "$(dirname "$dest")"
    wget -qO "$dest" "$REPO_BASE_URL/$module" || {
        echo "Ошибка: не удалось загрузить модуль '$module'"
        echo "Проверьте подключение к интернету и попробуйте снова."
        exit 1
    }
}

_load_modules() {
    for module in "${SCRIPT_MODULES[@]}"; do
        _download_module "$module"
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

    echo -e "  Статус службы:  ${status_label}"

    if [ -z "$installed_ver" ]; then
        ver_color="$YELLOW"
        ver_display="не установлена"
    elif [ "$installed_ver" = "$latest_ver" ]; then
        ver_color="$GREEN"
        ver_display="$installed_ver"
    else
        ver_color="$RED"
        ver_display="$installed_ver"
    fi

    echo -e "  Версия:         ${ver_color}${ver_display}${NC}"
    echo
    echo -e "${BOLD}──────────────────────────────────────────${NC}"
    echo
}

# ──────────────────────────────────────────────────────────────────────────────
# Рендер меню
# ──────────────────────────────────────────────────────────────────────────────
_render_menu() {
    if is_telemt_installed; then
        echo -e "  ${BOLD}1)${NC} Переустановить"
    else
        echo -e "  ${BOLD}1)${NC} Установить"
    fi
    echo -e "  ${BOLD}2)${NC} Обновить"
    echo -e "  ${BOLD}3)${NC} Удалить"
    echo
    echo -e "  ${BOLD}Enter)${NC} Выход"
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
        "") exit 0 ;;
        *)
            echo -e "${YELLOW}  Неверный выбор: '$choice'. Попробуйте ещё раз.${NC}"
            sleep 1
            ;;
    esac
}

_menu_loop() {
    while true; do
        _render_header
        _render_menu
        echo -n "  Ваш выбор: "
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
    _load_modules
    init_logging
    check_and_install_dependencies
    _menu_loop
}

main
