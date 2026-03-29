#!/usr/bin/env bash
# English localization

# ── Bootstrap ────────────────────────────────────────────────────────────────
MSG_WGET_NOT_FOUND="wget not found. Installing..."
MSG_WGET_INSTALL_FAILED="Error: failed to install wget. Install it manually and try again."
MSG_MODULE_DOWNLOAD_FAILED="Error: failed to download module"
MSG_CHECK_INTERNET="Check your internet connection and try again."

# ── Header ───────────────────────────────────────────────────────────────────
MSG_STATUS_LABEL="Service status:"
MSG_INSTALLED_VERSION_LABEL="Installed version:"
MSG_LATEST_VERSION_LABEL="Latest version:"
MSG_NOT_INSTALLED="not installed"

# ── Service status ───────────────────────────────────────────────────────────
MSG_SERVICE_NOT_INSTALLED="— Not installed"
MSG_SERVICE_RUNNING="● Running"
MSG_SERVICE_STOPPED="○ Stopped"

# ── Main menu ────────────────────────────────────────────────────────────────
MSG_MENU_INSTALL="Install"
MSG_MENU_REINSTALL="Reinstall"
MSG_MENU_UPDATE="Update"
MSG_MENU_UNINSTALL="Uninstall"
MSG_MENU_EDIT_CONFIG="Edit config"
MSG_MENU_EXIT="Exit"
MSG_YOUR_CHOICE="Your choice:"
MSG_INVALID_CHOICE="Invalid choice"

# ── Common / UI ──────────────────────────────────────────────────────────────
MSG_PRESS_ENTER="Press Enter to continue..."
MSG_CONFIRM_SUFFIX="[Y/n]:"
MSG_SESSION_STARTED="Session started"

# ── Dependencies ─────────────────────────────────────────────────────────────
MSG_CHECKING_DEPS="Checking dependencies..."
MSG_SYSTEMCTL_NOT_FOUND="systemctl not found. This script requires systemd."
MSG_MISSING_PACKAGES="Missing packages"
MSG_INSTALLING_SUFFIX="Installing..."
MSG_DEPS_INSTALLED="Dependencies installed"
MSG_APT_UPDATE_FAILED="Failed to run apt-get update"
MSG_INSTALLING_PACKAGE="Installing package:"
MSG_PACKAGE_INSTALL_FAILED="Failed to install"
MSG_PACKAGE_INSTALL_FAILED_SUFFIX="Install it manually and try again."

# ── Service management ───────────────────────────────────────────────────────
MSG_STARTING_SERVICE="Starting telemt service..."
MSG_STOPPING_SERVICE="Stopping telemt service..."
MSG_RESTARTING_SERVICE="Restarting telemt service..."
MSG_ENABLING_SERVICE="Enabling telemt autostart..."
MSG_DISABLING_SERVICE="Disabling telemt autostart..."

# ── Install ──────────────────────────────────────────────────────────────────
MSG_INSTALL_HEADER="── Telemt Installation ──────────────────────────"
MSG_INSTALL_AUTO="Automatic installation (default settings)"
MSG_INSTALL_MANUAL="Manual installation (choose port, domain, etc.)"
MSG_BACK="Back"
MSG_INVALID_CHOICE_RETRY="Invalid choice. Try again."

MSG_REINSTALL_START="Starting Telemt reinstallation..."
MSG_REINSTALL_DONE="Reinstallation complete"

MSG_AUTO_INSTALL_START="Starting automatic installation..."
MSG_PORT_BUSY="Port %s is busy. Use manual installation to choose another port."

MSG_MANUAL_INSTALL_START="Starting manual installation..."

MSG_DOWNLOADING_BINARY="Downloading binary..."
MSG_CREATING_USER="Creating system user..."
MSG_CREATING_CONFIG="Creating configuration..."
MSG_CREATING_SERVICE="Creating systemd service..."
MSG_STARTING_SERVICE_INSTALL="Starting service..."
MSG_INSTALL_DONE="Installation complete!"
MSG_INSTALL_SUMMARY="Port: %s  |  Domain: %s  |  User: %s"

MSG_DOWNLOADING_FILE="Downloading: %s"
MSG_DOWNLOAD_FAILED="Failed to download binary. Check your internet connection."
MSG_USER_EXISTS="System user '%s' already exists"

# ── Install prompts ──────────────────────────────────────────────────────────
MSG_PROMPT_PORT="Port [%s]:"
MSG_INVALID_PORT="Invalid port. Enter a number from 1 to 65535."
MSG_PORT_IN_USE="Port %s is busy. Enter another port."
MSG_PROMPT_DOMAIN="TLS domain [%s]:"
MSG_PROMPT_PUBLIC_HOST="Server domain (Enter to skip):"
MSG_PROMPT_USERNAME="Username [%s]:"
MSG_SECRET_PROMPT="Secret (32 hex chars, Enter to auto-generate):"
MSG_SECRET_HEADER="Secret (32 hex characters):"
MSG_SECRET_AUTO="Generate automatically"
MSG_SECRET_MANUAL="Enter manually"
MSG_SECRET_CHOICE="Choice [1]:"
MSG_SECRET_GENERATED="Generated secret:"
MSG_SECRET_INVALID_CHOICE="Invalid choice."
MSG_SECRET_ENTER="Enter secret (32 hex characters):"
MSG_SECRET_INVALID_FORMAT="Invalid format. Exactly 32 characters from 0-9 and a-f required."

# ── Existing config ─────────────────────────────────────────────────────────
MSG_CONFIG_EXISTS_REUSE="Existing configuration found. Reuse it? (if declined, it will be overwritten)"
MSG_CONFIG_REUSED="Using existing configuration."

# ── Proxy link ───────────────────────────────────────────────────────────────
MSG_FETCHING_LINK="Fetching link (waiting for API)..."
MSG_LINK_FAILED="Failed to get link. Try later:"
MSG_YOUR_LINK="Your link:"

# ── Uninstall ────────────────────────────────────────────────────────────────
MSG_NOT_INSTALLED_WARN="Telemt is not installed."
MSG_UNINSTALL_WARNING="This will completely remove Telemt from your server."
MSG_CONFIRM_UNINSTALL="Are you sure you want to uninstall Telemt?"
MSG_UNINSTALL_CANCELLED="Uninstall cancelled."
MSG_PRESERVE_CONFIG="Preserve configuration (%s/)?"
MSG_STOPPING_AND_DISABLING="Stopping and disabling service..."
MSG_REMOVING_SERVICE_FILE="Removing service file..."
MSG_REMOVING_BINARY="Removing binary..."
MSG_REMOVING_CONFIG="Removing configuration..."
MSG_CONFIG_PRESERVED="Configuration preserved: %s/"
MSG_REMOVING_USER="Removing system user..."
MSG_UNINSTALL_DONE="Telemt successfully uninstalled."

# ── Update ───────────────────────────────────────────────────────────────────
MSG_EDITING_CONFIG="Opening configuration in nano..."
MSG_CONFIG_NOT_FOUND="Configuration file not found. Install Telemt first."

# ── Users management ─────────────────────────────────────────────────────────
MSG_MENU_USERS="Users"
MSG_USERS_HEADER="── User Management ───────────────────────────────"
MSG_USERS_LIST_HEADER="Current users:"
MSG_USERS_EMPTY="No users found."
MSG_USERS_ADD="Add user"
MSG_USERS_REMOVE="Remove user"
MSG_USERS_ENTER_NAME="Username:"
MSG_USERS_NAME_EMPTY="Username cannot be empty."
MSG_USERS_NAME_INVALID="Username: 1–64 characters, allowed: A-Z a-z 0-9 _ - ."
MSG_USERS_ALREADY_EXISTS="User '%s' already exists."
MSG_USERS_ADDED="User '%s' added."
MSG_USERS_EDIT="Edit user"
MSG_USERS_SELECT_EDIT="User number to edit:"
MSG_USERS_EDIT_HEADER="── Editing user: %s ──"
MSG_USERS_EDIT_FIELD="Select parameter:"
MSG_USERS_UPDATED="User '%s' updated."
MSG_USERS_SELECT_REMOVE="User number to remove:"
MSG_USERS_CONFIRM_REMOVE="Remove user '%s'?"
MSG_USERS_REMOVED="User '%s' removed."
MSG_USERS_REMOVE_CANCELLED="Removal cancelled."
MSG_USERS_CANT_REMOVE_LAST="Cannot remove the last user."
MSG_USERS_SERVICE_NOT_RUNNING="Telemt service is not running. Start it before managing users."
MSG_USERS_API_ERROR="Failed to get data from API. Make sure the service is running."
MSG_USERS_SECRET_LABEL="Secret:"

# ── Users: optional params ──────────────────────────────────────────────────
MSG_USERS_CONFIGURE_PARAMS="Configure additional parameters?"
MSG_INSTALL_CONFIGURE_USER_PARAMS="Configure additional user parameters?"
MSG_USERS_SKIP_HINT="(Enter to skip)"
MSG_USERS_PARAM_SECRET="Secret (32 hex characters):"
MSG_USERS_PARAM_AD_TAG="Ad Tag (32 hex characters, from @MTProxybot):"
MSG_USERS_PARAM_MAX_TCP="Max TCP connections (number):"
MSG_USERS_PARAM_MAX_IPS="Max unique IPs (number):"
MSG_USERS_PARAM_EXPIRATION="Expiration (RFC 3339, e.g. 2026-12-31T00:00:00Z):"
MSG_USERS_PARAM_DATA_QUOTA="Data quota in bytes (e.g. 10737418240 = 10 GiB):"
MSG_USERS_INVALID_HEX32="Invalid format. Exactly 32 characters from 0-9 and a-f required."
MSG_USERS_INVALID_NUMBER="Must be a positive integer."
MSG_USERS_INVALID_RFC3339="Invalid RFC 3339 format. Example: 2026-12-31T00:00:00Z"

# ── Users: display labels ───────────────────────────────────────────────────
MSG_USERS_LABEL_LINK="Link:"
MSG_USERS_LABEL_AD_TAG="Ad Tag:"
MSG_USERS_LABEL_MAX_TCP="Max TCP:"
MSG_USERS_LABEL_MAX_IPS="Max IPs:"
MSG_USERS_LABEL_EXPIRATION="Expires:"
MSG_USERS_LABEL_DATA_QUOTA="Quota:"
MSG_USERS_LABEL_UNLIMITED="unlimited"
MSG_USERS_LABEL_PERMANENT="permanent"
MSG_USERS_LABEL_NOT_SET="not set"
MSG_USERS_PAGE_INFO="Page %s of %s (total: %s)"
MSG_USERS_PAGE_NEXT="Next page"
MSG_USERS_PAGE_PREV="Previous page"

# ── Users: edit menu short labels ───────────────────────────────────────────
MSG_USERS_EDIT_SECRET="Secret:"
MSG_USERS_EDIT_AD_TAG="Ad Tag:"
MSG_USERS_EDIT_MAX_TCP="Max TCP:"
MSG_USERS_EDIT_MAX_IPS="Max IPs:"
MSG_USERS_EDIT_EXPIRATION="Expires:"
MSG_USERS_EDIT_DATA_QUOTA="Quota:"

# ── Metrics ──────────────────────────────────────────────────────────────────
MSG_MENU_METRICS_ENABLE="Enable metrics"
MSG_MENU_METRICS_DISABLE="Disable metrics"
MSG_METRICS_PROMPT_IP="IP in CIDR notation for metrics access (Enter — open to all, example: 1.2.3.4/32):"
MSG_METRICS_ENABLED="Metrics enabled. Port: %s | Access: %s"
MSG_METRICS_DISABLED="Metrics disabled."
MSG_METRICS_CONFIG_ERROR="Failed to update configuration."
MSG_METRICS_LINKS_HEADER="Metrics links:"

MSG_NOT_INSTALLED_UPDATE="Telemt is not installed. Install it first."
MSG_CURRENT_VERSION="Current version:  %s"
MSG_LATEST_VERSION="Latest version:   %s"
MSG_ALREADY_LATEST="You already have the latest version: %s"
MSG_CONFIRM_UPDATE="Update Telemt to version %s?"
MSG_UPDATE_CANCELLED="Update cancelled."
MSG_DOWNLOADING_NEW="Downloading new version..."
MSG_UPDATE_DOWNLOAD_FAILED="Failed to download new binary. Starting previous version..."
MSG_UPDATE_DONE="Update complete. Installed version: %s"
