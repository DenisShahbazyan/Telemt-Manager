#!/usr/bin/env bash
# Русская локализация

# ── Bootstrap ────────────────────────────────────────────────────────────────
MSG_WGET_NOT_FOUND="wget не найден. Установка..."
MSG_WGET_INSTALL_FAILED="Ошибка: не удалось установить wget. Установите вручную и повторите."
MSG_MODULE_DOWNLOAD_FAILED="Ошибка: не удалось загрузить модуль"
MSG_CHECK_INTERNET="Проверьте подключение к интернету и попробуйте снова."

# ── Header ───────────────────────────────────────────────────────────────────
MSG_STATUS_LABEL="Статус службы:"
MSG_INSTALLED_VERSION_LABEL="Установленная версия:"
MSG_LATEST_VERSION_LABEL="Актуальная версия:"
MSG_NOT_INSTALLED="не установлена"

# ── Service status ───────────────────────────────────────────────────────────
MSG_SERVICE_NOT_INSTALLED="— Не установлена"
MSG_SERVICE_RUNNING="● Запущена"
MSG_SERVICE_STOPPED="○ Остановлена"

# ── Main menu ────────────────────────────────────────────────────────────────
MSG_MENU_INSTALL="Установить"
MSG_MENU_REINSTALL="Переустановить"
MSG_MENU_UPDATE="Обновить"
MSG_MENU_UNINSTALL="Удалить"
MSG_MENU_EDIT_CONFIG="Редактировать конфиг"
MSG_MENU_EXIT="Выход"
MSG_YOUR_CHOICE="Ваш выбор:"
MSG_INVALID_CHOICE="Неверный выбор"

# ── Common / UI ──────────────────────────────────────────────────────────────
MSG_PRESS_ENTER="Нажмите Enter для продолжения..."
MSG_CONFIRM_SUFFIX="[Y/n]:"
MSG_SESSION_STARTED="Сеанс начат"

# ── Dependencies ─────────────────────────────────────────────────────────────
MSG_CHECKING_DEPS="Проверка зависимостей..."
MSG_SYSTEMCTL_NOT_FOUND="systemctl не найден. Скрипт требует systemd."
MSG_MISSING_PACKAGES="Отсутствуют пакеты"
MSG_INSTALLING_SUFFIX="Установка..."
MSG_DEPS_INSTALLED="Зависимости установлены"
MSG_APT_UPDATE_FAILED="Не удалось выполнить apt-get update"
MSG_INSTALLING_PACKAGE="Установка пакета:"
MSG_PACKAGE_INSTALL_FAILED="Не удалось установить"
MSG_PACKAGE_INSTALL_FAILED_SUFFIX="Установите вручную и повторите."

# ── Service management ───────────────────────────────────────────────────────
MSG_STARTING_SERVICE="Запуск службы telemt..."
MSG_STOPPING_SERVICE="Остановка службы telemt..."
MSG_RESTARTING_SERVICE="Перезапуск службы telemt..."
MSG_ENABLING_SERVICE="Включение автозапуска службы telemt..."
MSG_DISABLING_SERVICE="Отключение автозапуска службы telemt..."

# ── Install ──────────────────────────────────────────────────────────────────
MSG_INSTALL_HEADER="── Установка Telemt ──────────────────────────────"
MSG_INSTALL_AUTO="Автоматическая установка (дефолтные настройки)"
MSG_INSTALL_MANUAL="Ручная установка (выбор порта, домена и т.д.)"
MSG_BACK="Назад"
MSG_INVALID_CHOICE_RETRY="Неверный выбор. Попробуйте ещё раз."

MSG_REINSTALL_START="Начало переустановки Telemt..."
MSG_REINSTALL_DONE="Переустановка завершена"

MSG_AUTO_INSTALL_START="Начало автоматической установки..."
MSG_PORT_BUSY="Порт %s занят. Используйте ручную установку для выбора другого порта."

MSG_MANUAL_INSTALL_START="Начало ручной установки..."

MSG_DOWNLOADING_BINARY="Скачивание бинарного файла..."
MSG_CREATING_USER="Создание системного пользователя..."
MSG_CREATING_CONFIG="Создание конфигурации..."
MSG_CREATING_SERVICE="Создание systemd службы..."
MSG_STARTING_SERVICE_INSTALL="Запуск службы..."
MSG_INSTALL_DONE="Установка завершена!"
MSG_INSTALL_SUMMARY="Порт: %s  |  Домен: %s  |  Пользователь: %s"

MSG_DOWNLOADING_FILE="Скачивание: %s"
MSG_DOWNLOAD_FAILED="Не удалось скачать бинарный файл. Проверьте подключение к интернету."
MSG_USER_EXISTS="Системный пользователь '%s' уже существует"

# ── Install prompts ──────────────────────────────────────────────────────────
MSG_PROMPT_PORT="Порт [%s]:"
MSG_INVALID_PORT="Некорректный порт. Введите число от 1 до 65535."
MSG_PORT_IN_USE="Порт %s занят. Введите другой порт."
MSG_PROMPT_DOMAIN="TLS домен [%s]:"
MSG_PROMPT_USERNAME="Имя пользователя [%s]:"
MSG_SECRET_PROMPT="Секрет (32 hex символа, Enter — сгенерировать):"
MSG_SECRET_HEADER="Секрет (32 hex символа):"
MSG_SECRET_AUTO="Сгенерировать автоматически"
MSG_SECRET_MANUAL="Ввести вручную"
MSG_SECRET_CHOICE="Выбор [1]:"
MSG_SECRET_GENERATED="Сгенерирован секрет:"
MSG_SECRET_INVALID_CHOICE="Неверный выбор."
MSG_SECRET_ENTER="Введите секрет (32 hex символа):"
MSG_SECRET_INVALID_FORMAT="Неверный формат. Требуется ровно 32 символа из набора 0-9 и a-f."

# ── Existing config ─────────────────────────────────────────────────────────
MSG_CONFIG_EXISTS_REUSE="Найдена существующая конфигурация. Использовать её? (при отказе она будет перезаписана)"
MSG_CONFIG_REUSED="Используется существующая конфигурация."

# ── Proxy link ───────────────────────────────────────────────────────────────
MSG_FETCHING_LINK="Получение ссылки (ожидание готовности API)..."
MSG_LINK_FAILED="Не удалось получить ссылку. Попробуйте позже:"
MSG_YOUR_LINK="Ваша ссылка:"

# ── Uninstall ────────────────────────────────────────────────────────────────
MSG_NOT_INSTALLED_WARN="Telemt не установлен."
MSG_UNINSTALL_WARNING="Это действие полностью удалит Telemt с вашего сервера."
MSG_CONFIRM_UNINSTALL="Вы уверены, что хотите удалить Telemt?"
MSG_UNINSTALL_CANCELLED="Удаление отменено."
MSG_PRESERVE_CONFIG="Сохранить конфигурацию (%s/)?"
MSG_STOPPING_AND_DISABLING="Остановка и отключение службы..."
MSG_REMOVING_SERVICE_FILE="Удаление файла службы..."
MSG_REMOVING_BINARY="Удаление бинарного файла..."
MSG_REMOVING_CONFIG="Удаление конфигурации..."
MSG_CONFIG_PRESERVED="Конфигурация сохранена: %s/"
MSG_REMOVING_USER="Удаление системного пользователя..."
MSG_UNINSTALL_DONE="Telemt успешно удалён."

# ── Update ───────────────────────────────────────────────────────────────────
MSG_EDITING_CONFIG="Открытие конфигурации в nano..."
MSG_CONFIG_NOT_FOUND="Файл конфигурации не найден. Сначала установите Telemt."

# ── Users management ─────────────────────────────────────────────────────────
MSG_MENU_USERS="Пользователи"
MSG_USERS_HEADER="── Управление пользователями ─────────────────────"
MSG_USERS_LIST_HEADER="Текущие пользователи:"
MSG_USERS_EMPTY="Пользователи не найдены."
MSG_USERS_ADD="Добавить пользователя"
MSG_USERS_REMOVE="Удалить пользователя"
MSG_USERS_ENTER_NAME="Имя пользователя:"
MSG_USERS_NAME_EMPTY="Имя пользователя не может быть пустым."
MSG_USERS_NAME_INVALID="Имя пользователя: 1–64 символа, допустимы A-Z a-z 0-9 _ - ."
MSG_USERS_ALREADY_EXISTS="Пользователь '%s' уже существует."
MSG_USERS_ADDED="Пользователь '%s' добавлен."
MSG_USERS_EDIT="Редактировать пользователя"
MSG_USERS_SELECT_EDIT="Номер пользователя для редактирования:"
MSG_USERS_EDIT_HEADER="── Редактирование пользователя: %s ──"
MSG_USERS_EDIT_FIELD="Выберите параметр:"
MSG_USERS_UPDATED="Пользователь '%s' обновлён."
MSG_USERS_SELECT_REMOVE="Номер пользователя для удаления:"
MSG_USERS_CONFIRM_REMOVE="Удалить пользователя '%s'?"
MSG_USERS_REMOVED="Пользователь '%s' удалён."
MSG_USERS_REMOVE_CANCELLED="Удаление отменено."
MSG_USERS_CANT_REMOVE_LAST="Нельзя удалить последнего пользователя."
MSG_USERS_SERVICE_NOT_RUNNING="Служба Telemt не запущена. Запустите перед управлением пользователями."
MSG_USERS_API_ERROR="Не удалось получить данные от API. Проверьте, что служба запущена."
MSG_USERS_SECRET_LABEL="Секрет:"

# ── Users: optional params ──────────────────────────────────────────────────
MSG_USERS_CONFIGURE_PARAMS="Настроить дополнительные параметры?"
MSG_INSTALL_CONFIGURE_USER_PARAMS="Настроить дополнительные параметры пользователя?"
MSG_USERS_SKIP_HINT="(Enter — пропустить)"
MSG_USERS_PARAM_SECRET="Секрет (32 hex символа):"
MSG_USERS_PARAM_AD_TAG="Ad Tag (32 hex символа, из @MTProxybot):"
MSG_USERS_PARAM_MAX_TCP="Макс. TCP-соединений (число):"
MSG_USERS_PARAM_MAX_IPS="Макс. уникальных IP (число):"
MSG_USERS_PARAM_EXPIRATION="Срок действия (RFC 3339, напр. 2026-12-31T00:00:00Z):"
MSG_USERS_PARAM_DATA_QUOTA="Квота трафика в байтах (напр. 10737418240 = 10 GiB):"
MSG_USERS_INVALID_HEX32="Неверный формат. Требуется ровно 32 символа из набора 0-9 и a-f."
MSG_USERS_INVALID_NUMBER="Требуется положительное целое число."
MSG_USERS_INVALID_RFC3339="Неверный формат RFC 3339. Пример: 2026-12-31T00:00:00Z"

# ── Users: display labels ───────────────────────────────────────────────────
MSG_USERS_LABEL_LINK="Ссылка:"
MSG_USERS_LABEL_AD_TAG="Ad Tag:"
MSG_USERS_LABEL_MAX_TCP="Макс. TCP:"
MSG_USERS_LABEL_MAX_IPS="Макс. IP:"
MSG_USERS_LABEL_EXPIRATION="Истекает:"
MSG_USERS_LABEL_DATA_QUOTA="Квота:"
MSG_USERS_LABEL_UNLIMITED="без ограничений"
MSG_USERS_LABEL_PERMANENT="бессрочно"
MSG_USERS_LABEL_NOT_SET="не задан"
MSG_USERS_PAGE_INFO="Страница %s из %s (всего: %s)"
MSG_USERS_PAGE_NEXT="Следующая страница"
MSG_USERS_PAGE_PREV="Предыдущая страница"

# ── Users: edit menu short labels ───────────────────────────────────────────
MSG_USERS_EDIT_SECRET="Секрет:"
MSG_USERS_EDIT_AD_TAG="Ad Tag:"
MSG_USERS_EDIT_MAX_TCP="Макс. TCP:"
MSG_USERS_EDIT_MAX_IPS="Макс. IP:"
MSG_USERS_EDIT_EXPIRATION="Истекает:"
MSG_USERS_EDIT_DATA_QUOTA="Квота:"

MSG_NOT_INSTALLED_UPDATE="Telemt не установлен. Сначала выполните установку."
MSG_CURRENT_VERSION="Текущая версия:  %s"
MSG_LATEST_VERSION="Актуальная:      %s"
MSG_ALREADY_LATEST="У вас уже установлена актуальная версия: %s"
MSG_CONFIRM_UPDATE="Обновить Telemt до версии %s?"
MSG_UPDATE_CANCELLED="Обновление отменено."
MSG_DOWNLOADING_NEW="Скачивание новой версии..."
MSG_UPDATE_DOWNLOAD_FAILED="Не удалось скачать новый бинарный файл. Запуск предыдущей версии..."
MSG_UPDATE_DONE="Обновление завершено. Установленная версия: %s"
