#!/usr/bin/env bash
# Общие утилиты: цвета, логирование, зависимости, состояние службы, версии

# ──────────────────────────────────────────────────────────────────────────────
# Цвета и стили
# ──────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ──────────────────────────────────────────────────────────────────────────────
# Пути Telemt (используются во всех модулях)
# ──────────────────────────────────────────────────────────────────────────────
TELEMT_BIN="/bin/telemt"
TELEMT_CONFIG_DIR="/etc/telemt"
TELEMT_CONFIG_FILE="/etc/telemt/telemt.toml"
TELEMT_SERVICE_FILE="/etc/systemd/system/telemt.service"
TELEMT_SYSTEM_USER="telemt"
TELEMT_WORKDIR="/opt/telemt"
TELEMT_API_LISTEN="127.0.0.1:9091"

# ──────────────────────────────────────────────────────────────────────────────
# Логирование
# ──────────────────────────────────────────────────────────────────────────────
LOG_DIR="/var/log/telemt"
LOG_FILE=""

init_logging() {
    sudo mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/telemt-manager-$(date '+%Y-%m-%d_%H-%M-%S').log"
    sudo touch "$LOG_FILE"
    sudo chown "$(id -un)" "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    _write_log "INFO" "${MSG_SESSION_STARTED}: $(date '+%Y-%m-%d %H:%M:%S')"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC}  $1"
    _write_log "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}[ OK ]${NC}  $1"
    _write_log "OK" "$1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC}  $1"
    _write_log "WARN" "$1"
}

log_error() {
    echo -e "${RED}[ERR ]${NC}  $1"
    _write_log "ERROR" "$1"
}

_write_log() {
    local level="$1"
    local message="$2"
    [ -n "$LOG_FILE" ] || return 0
    [ -f "$LOG_FILE" ] || return 0
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# ──────────────────────────────────────────────────────────────────────────────
# Зависимости
# ──────────────────────────────────────────────────────────────────────────────
REQUIRED_DEPS=("jq" "openssl" "curl")

check_and_install_dependencies() {
    log_info "$MSG_CHECKING_DEPS"

    if ! command -v systemctl &>/dev/null; then
        log_error "$MSG_SYSTEMCTL_NOT_FOUND"
        exit 1
    fi

    local missing_pkgs=()
    for dep in "${REQUIRED_DEPS[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_pkgs+=("$dep")
        fi
    done

    if [ "${#missing_pkgs[@]}" -eq 0 ]; then
        return 0
    fi

    log_warn "${MSG_MISSING_PACKAGES}: ${missing_pkgs[*]}. ${MSG_INSTALLING_SUFFIX}"
    _apt_update
    for pkg in "${missing_pkgs[@]}"; do
        _apt_install "$pkg"
    done
    log_success "$MSG_DEPS_INSTALLED"
}

_apt_update() {
    sudo apt-get update -qq || {
        log_error "$MSG_APT_UPDATE_FAILED"
        exit 1
    }
}

_apt_install() {
    local pkg="$1"
    log_info "${MSG_INSTALLING_PACKAGE} $pkg"
    sudo apt-get install -y "$pkg" || {
        log_error "${MSG_PACKAGE_INSTALL_FAILED} '$pkg'. ${MSG_PACKAGE_INSTALL_FAILED_SUFFIX}"
        exit 1
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Состояние Telemt
# ──────────────────────────────────────────────────────────────────────────────
is_telemt_installed() {
    [ -f "$TELEMT_BIN" ]
}

get_service_status() {
    systemctl is-active telemt 2>/dev/null || true
}

get_service_status_label() {
    if ! is_telemt_installed; then
        echo -e "${YELLOW}${MSG_SERVICE_NOT_INSTALLED}${NC}"
        return
    fi

    local status
    status=$(get_service_status)

    if [ "$status" = "active" ]; then
        echo -e "${GREEN}${MSG_SERVICE_RUNNING}${NC}"
    else
        echo -e "${RED}${MSG_SERVICE_STOPPED}${NC}"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Версии
# ──────────────────────────────────────────────────────────────────────────────
get_installed_version() {
    is_telemt_installed || { echo ""; return; }
    "$TELEMT_BIN" --version 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
        | head -1 \
        || echo ""
}

get_latest_version() {
    wget -qO- "https://api.github.com/repos/telemt/telemt/releases/latest" 2>/dev/null \
        | jq -r '.tag_name // "N/A"' \
        | sed 's/^v//' \
        || echo "N/A"
}

# ──────────────────────────────────────────────────────────────────────────────
# Управление службой systemd
# ──────────────────────────────────────────────────────────────────────────────
start_telemt_service() {
    log_info "$MSG_STARTING_SERVICE"
    sudo systemctl start telemt
}

stop_telemt_service() {
    systemctl is-active --quiet telemt 2>/dev/null || return 0
    log_info "$MSG_STOPPING_SERVICE"
    sudo systemctl stop telemt
}

restart_telemt_service() {
    log_info "$MSG_RESTARTING_SERVICE"
    sudo systemctl restart telemt
}

enable_telemt_service() {
    log_info "$MSG_ENABLING_SERVICE"
    sudo systemctl enable telemt &>/dev/null
}

disable_telemt_service() {
    systemctl is-enabled --quiet telemt 2>/dev/null || return 0
    log_info "$MSG_DISABLING_SERVICE"
    sudo systemctl disable telemt &>/dev/null
}

reload_systemd() {
    sudo systemctl daemon-reload
}

reset_failed_systemd() {
    sudo systemctl reset-failed 2>/dev/null || true
}

# ──────────────────────────────────────────────────────────────────────────────
# Общие UI-утилиты
# ──────────────────────────────────────────────────────────────────────────────
press_enter_to_continue() {
    echo
    echo -n "  ${MSG_PRESS_ENTER} "
    read -r
}

confirm_action() {
    local prompt="$1"
    local answer
    echo -n "  ${prompt} ${MSG_CONFIRM_SUFFIX} "
    read -r answer
    [[ -z "$answer" || "$answer" =~ ^[yY]$ ]]
}
