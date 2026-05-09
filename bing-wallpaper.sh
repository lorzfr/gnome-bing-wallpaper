#!/usr/bin/env bash
set -euo pipefail

APP_NAME="gnome-bing-wallpaper"
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/${APP_NAME}"
CONFIG_FILE="${CONFIG_DIR}/config"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
SERVICE_FILE="${SYSTEMD_USER_DIR}/${APP_NAME}.service"
TIMER_FILE="${SYSTEMD_USER_DIR}/${APP_NAME}.timer"

DEFAULT_SOURCE="bing"
DEFAULT_ENABLED="true"
DEFAULT_UPDATE_INTERVAL="24h"
DEFAULT_ON_BOOT_DELAY="2min"
DEFAULT_TARGET_DIR="${HOME}/Pictures"
DEFAULT_CURL_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) ${APP_NAME}"

SOURCE="${DEFAULT_SOURCE}"
ENABLED="${DEFAULT_ENABLED}"
UPDATE_INTERVAL="${DEFAULT_UPDATE_INTERVAL}"
ON_BOOT_DELAY="${DEFAULT_ON_BOOT_DELAY}"
TARGET_DIR="${DEFAULT_TARGET_DIR}"
TARGET_FILE=""
CURL_USER_AGENT="${DEFAULT_CURL_USER_AGENT}"
BING_MARKET_VALUE="${BING_MARKET:-de-DE}"
BING_RESOLUTION_VALUE="${BING_RESOLUTION:-UHD}"
NASA_API_KEY_VALUE="${NASA_API_KEY:-DEMO_KEY}"
NASA_APOD_FALLBACK_COUNT_VALUE="${NASA_APOD_FALLBACK_COUNT:-10}"
ESA_IMAGES_URL_VALUE="${ESA_IMAGES_URL:-https://www.esa.int/ESA_Multimedia/Images}"

FULL_URL=""
SOURCE_LABEL=""
SOURCE_TITLE=""
BING_FALLBACK_URL=""

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[ERR]\033[0m  %s\n' "$*" >&2; }

html_unescape() {
  sed \
    -e 's/&amp;/\&/g' \
    -e 's/&quot;/"/g' \
    -e "s/&#39;/'/g" \
    -e 's/&lt;/</g' \
    -e 's/&gt;/>/g'
}

absolute_url() {
  url="$1"
  base="$2"

  case "${url}" in
    http://*|https://*) printf '%s\n' "${url}" ;;
    //*) printf 'https:%s\n' "${url}" ;;
    /*) printf '%s%s\n' "${base}" "${url}" ;;
    *) printf '%s/%s\n' "${base}" "${url}" ;;
  esac
}

shell_quote() {
  value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

normalize_bool() {
  case "${1,,}" in
    1|true|yes|y|on|enabled) printf 'true\n' ;;
    0|false|no|n|off|disabled) printf 'false\n' ;;
    *) return 1 ;;
  esac
}

validate_interval() {
  [[ "$1" =~ ^[1-9][0-9]*(s|min|h|d|w|month)$ ]]
}

supported_sources() {
  printf 'bing\nnasa\nesa\n'
}

source_label() {
  case "$1" in
    bing) printf 'Bing daily wallpaper\n' ;;
    nasa|apod) printf 'NASA APOD\n' ;;
    esa) printf 'ESA Images\n' ;;
    *) printf 'Unknown\n' ;;
  esac
}

load_config() {
  if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    . "${CONFIG_FILE}"
  fi

  SOURCE="${WALLPAPER_SOURCE:-${SOURCE:-${DEFAULT_SOURCE}}}"
  ENABLED="$(normalize_bool "${WALLPAPER_ENABLED:-${ENABLED:-${DEFAULT_ENABLED}}}" || printf '%s\n' "${DEFAULT_ENABLED}")"
  UPDATE_INTERVAL="${WALLPAPER_UPDATE_INTERVAL:-${UPDATE_INTERVAL:-${DEFAULT_UPDATE_INTERVAL}}}"
  ON_BOOT_DELAY="${WALLPAPER_ON_BOOT_DELAY:-${ON_BOOT_DELAY:-${DEFAULT_ON_BOOT_DELAY}}}"
  TARGET_DIR="${WALLPAPER_TARGET_DIR:-${TARGET_DIR:-${DEFAULT_TARGET_DIR}}}"
  TARGET_FILE="${WALLPAPER_TARGET_FILE:-${TARGET_FILE:-}}"
  CURL_USER_AGENT="${WALLPAPER_USER_AGENT:-${CURL_USER_AGENT:-${BING_USER_AGENT:-${DEFAULT_CURL_USER_AGENT}}}}"
  BING_MARKET_VALUE="${BING_MARKET:-${BING_MARKET_VALUE:-de-DE}}"
  BING_RESOLUTION_VALUE="${BING_RESOLUTION:-${BING_RESOLUTION_VALUE:-UHD}}"
  NASA_API_KEY_VALUE="${NASA_API_KEY:-${NASA_API_KEY_VALUE:-DEMO_KEY}}"
  NASA_APOD_FALLBACK_COUNT_VALUE="${NASA_APOD_FALLBACK_COUNT:-${NASA_APOD_FALLBACK_COUNT_VALUE:-10}}"
  ESA_IMAGES_URL_VALUE="${ESA_IMAGES_URL:-${ESA_IMAGES_URL_VALUE:-https://www.esa.int/ESA_Multimedia/Images}}"
}

save_config() {
  mkdir -p "${CONFIG_DIR}"
  cat > "${CONFIG_FILE}" <<CONFIG
# ${APP_NAME} configuration
# Edit this file directly or run: ${APP_NAME} configure
WALLPAPER_SOURCE=$(shell_quote "${SOURCE}")
WALLPAPER_ENABLED=$(shell_quote "${ENABLED}")
WALLPAPER_UPDATE_INTERVAL=$(shell_quote "${UPDATE_INTERVAL}")
WALLPAPER_ON_BOOT_DELAY=$(shell_quote "${ON_BOOT_DELAY}")
WALLPAPER_TARGET_DIR=$(shell_quote "${TARGET_DIR}")
WALLPAPER_TARGET_FILE=$(shell_quote "${TARGET_FILE}")
WALLPAPER_USER_AGENT=$(shell_quote "${CURL_USER_AGENT}")
BING_MARKET=$(shell_quote "${BING_MARKET_VALUE}")
BING_RESOLUTION=$(shell_quote "${BING_RESOLUTION_VALUE}")
NASA_API_KEY=$(shell_quote "${NASA_API_KEY_VALUE}")
NASA_APOD_FALLBACK_COUNT=$(shell_quote "${NASA_APOD_FALLBACK_COUNT_VALUE}")
ESA_IMAGES_URL=$(shell_quote "${ESA_IMAGES_URL_VALUE}")
CONFIG
  chmod 0600 "${CONFIG_FILE}"
}

validate_config() {
  case "${SOURCE}" in
    bing|nasa|apod|esa) ;;
    *) error "Unsupported source '${SOURCE}'. Use one of: bing, nasa, esa."; exit 1 ;;
  esac

  if ! validate_interval "${UPDATE_INTERVAL}"; then
    error "Invalid update interval '${UPDATE_INTERVAL}'. Use values like 30min, 12h, 1d, or 1w."
    exit 1
  fi

  if ! validate_interval "${ON_BOOT_DELAY}"; then
    error "Invalid boot delay '${ON_BOOT_DELAY}'. Use values like 30s, 2min, or 1h."
    exit 1
  fi
}

fetch_bing_metadata() {
  market="${BING_MARKET_VALUE}"
  resolution="${BING_RESOLUTION_VALUE}"
  api_url="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=${market}"

  image_json="$(curl -fsSL -A "${CURL_USER_AGENT}" "${api_url}" | jq -e '.images[0]')"
  url_path="$(jq -r '.url // empty' <<<"${image_json}")"
  url_base="$(jq -r '.urlbase // empty' <<<"${image_json}")"
  SOURCE_TITLE="$(jq -r '.title // .copyright // "Bing daily wallpaper"' <<<"${image_json}")"

  if [[ -z "${url_path}" || "${url_path}" == "null" ]]; then
    error "Bing API did not return a wallpaper URL for market ${market}."
    exit 1
  fi

  if [[ -n "${url_base}" && "${url_base}" != "null" ]]; then
    FULL_URL="https://www.bing.com${url_base}_${resolution}.jpg"
  else
    FULL_URL="https://www.bing.com${url_path}"
  fi

  BING_FALLBACK_URL="https://www.bing.com${url_path}"
  SOURCE_LABEL="Bing"
}

fetch_nasa_metadata() {
  api_key="${NASA_API_KEY_VALUE}"
  api_url="https://api.nasa.gov/planetary/apod?api_key=${api_key}"

  image_json="$(curl -fsSL -A "${CURL_USER_AGENT}" "${api_url}" | jq -e '.')"
  media_type="$(jq -r '.media_type // empty' <<<"${image_json}")"

  if [[ "${media_type}" != "image" ]]; then
    fallback_count="${NASA_APOD_FALLBACK_COUNT_VALUE}"
    image_json="$(curl -fsSL -A "${CURL_USER_AGENT}" "https://api.nasa.gov/planetary/apod?api_key=${api_key}&count=${fallback_count}" | jq -e '[.[] | select(.media_type == "image")][0]')"
  fi

  FULL_URL="$(jq -r '.hdurl // .url // empty' <<<"${image_json}")"
  SOURCE_TITLE="$(jq -r '.title // "NASA Astronomy Picture of the Day"' <<<"${image_json}")"

  if [[ -z "${FULL_URL}" || "${FULL_URL}" == "null" ]]; then
    error "NASA APOD API did not return an image URL."
    exit 1
  fi

  SOURCE_LABEL="NASA APOD"
}

fetch_esa_metadata() {
  index_url="${ESA_IMAGES_URL_VALUE}"
  index_html="$(curl -fsSL -A "${CURL_USER_AGENT}" "${index_url}")"

  image_page="$(printf '%s' "${index_html}" \
    | sed -nE 's/.*href="([^"]*\/ESA_Multimedia\/Images\/[0-9]{4}\/[0-9]{2}\/[^"]+)".*/\1/p' \
    | head -n 1 \
    | html_unescape)"

  if [[ -z "${image_page}" ]]; then
    error "ESA image listing did not contain an image page link."
    exit 1
  fi

  image_page="$(absolute_url "${image_page}" "https://www.esa.int")"
  page_html="$(curl -fsSL -A "${CURL_USER_AGENT}" "${image_page}")"

  FULL_URL="$(printf '%s' "${page_html}" \
    | sed -nE 's/.*property="og:image(:secure_url)?" content="([^"]+)".*/\2/p; s/.*name="twitter:image" content="([^"]+)".*/\1/p' \
    | head -n 1 \
    | html_unescape)"
  SOURCE_TITLE="$(printf '%s' "${page_html}" \
    | sed -nE 's/.*property="og:title" content="([^"]+)".*/\1/p' \
    | head -n 1 \
    | html_unescape)"

  if [[ -z "${FULL_URL}" ]]; then
    error "ESA image page did not contain an Open Graph image URL: ${image_page}"
    exit 1
  fi

  FULL_URL="$(absolute_url "${FULL_URL}" "https://www.esa.int")"
  SOURCE_LABEL="ESA Images"
}

select_wallpaper_source() {
  case "${SOURCE}" in
    bing) fetch_bing_metadata ;;
    nasa|apod) fetch_nasa_metadata ;;
    esa) fetch_esa_metadata ;;
    *) error "Unsupported source '${SOURCE}'. Use one of: bing, nasa, esa."; exit 1 ;;
  esac
}

download_wallpaper() {
  mkdir -p "${TARGET_DIR}"
  target_file="${TARGET_FILE:-${TARGET_DIR}/${SOURCE}-wallpaper.jpg}"
  temp_file="$(mktemp "${TARGET_DIR}/${SOURCE}-wallpaper.XXXXXX")"
  cleanup() {
    rm -f "${temp_file}"
  }
  trap cleanup EXIT

  if ! curl -fsSL -A "${CURL_USER_AGENT}" -o "${temp_file}" "${FULL_URL}"; then
    if [[ "${SOURCE}" == "bing" && "${FULL_URL}" != "${BING_FALLBACK_URL}" ]]; then
      warn "Could not download ${BING_RESOLUTION_VALUE} wallpaper; falling back to Bing default image."
      curl -fsSL -A "${CURL_USER_AGENT}" -o "${temp_file}" "${BING_FALLBACK_URL}"
      FULL_URL="${BING_FALLBACK_URL}"
    else
      error "Failed to download ${SOURCE_LABEL} wallpaper from ${FULL_URL}."
      exit 1
    fi
  fi

  mv "${temp_file}" "${target_file}"
  trap - EXIT

  gsettings set org.gnome.desktop.background picture-uri "file://${target_file}"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://${target_file}"

  success "Wallpaper updated: ${target_file}"
  echo "Source (${SOURCE_LABEL}): ${FULL_URL}"
  if [[ -n "${SOURCE_TITLE}" ]]; then
    echo "Title: ${SOURCE_TITLE}"
  fi
}

write_systemd_units() {
  mkdir -p "${SYSTEMD_USER_DIR}"
  cat > "${SERVICE_FILE}" <<UNIT
[Unit]
Description=Set GNOME wallpaper from configured image source
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/${APP_NAME} run
UNIT

  cat > "${TIMER_FILE}" <<UNIT
[Unit]
Description=Run GNOME wallpaper updater

[Timer]
OnBootSec=${ON_BOOT_DELAY}
OnUnitActiveSec=${UPDATE_INTERVAL}
Persistent=true

[Install]
WantedBy=timers.target
UNIT
}

systemctl_user() {
  systemctl --user "$@"
}

apply_schedule() {
  validate_config
  save_config
  write_systemd_units

  if ! systemctl_user daemon-reload; then
    warn "Saved configuration and systemd units, but could not reload the systemd user manager."
    warn "Run 'systemctl --user daemon-reload' after logging into a systemd user session."
    return 0
  fi

  if [[ "${ENABLED}" == "true" ]]; then
    if systemctl_user enable --now "${APP_NAME}.timer"; then
      success "Wallpaper timer enabled (${UPDATE_INTERVAL})."
    else
      warn "Saved configuration, but could not enable ${APP_NAME}.timer."
    fi
  else
    if systemctl_user disable --now "${APP_NAME}.timer" >/dev/null 2>&1; then
      success "Wallpaper timer disabled."
    else
      warn "Saved configuration, but could not disable ${APP_NAME}.timer. It may already be disabled."
    fi
  fi
}

print_status() {
  load_config
  printf '%s configuration\n' "${APP_NAME}"
  printf '  Config file: %s\n' "${CONFIG_FILE}"
  printf '  Enabled: %s\n' "${ENABLED}"
  printf '  Source: %s (%s)\n' "${SOURCE}" "$(source_label "${SOURCE}")"
  printf '  Update interval: %s\n' "${UPDATE_INTERVAL}"
  printf '  Boot delay: %s\n' "${ON_BOOT_DELAY}"
  printf '  Target directory: %s\n' "${TARGET_DIR}"
  if [[ -n "${TARGET_FILE}" ]]; then
    printf '  Target file: %s\n' "${TARGET_FILE}"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl_user --quiet is-enabled "${APP_NAME}.timer" >/dev/null 2>&1; then
      printf '  Systemd timer: enabled\n'
    else
      printf '  Systemd timer: disabled or not installed\n'
    fi
  fi
}

prompt_value() {
  label="$1"
  current="$2"
  value=""
  printf '%s [%s]: ' "${label}" "${current}"
  read -r value
  printf '%s\n' "${value:-${current}}"
}

prompt_bool() {
  label="$1"
  current="$2"
  value=""
  while true; do
    printf '%s (y/n) [%s]: ' "${label}" "$([[ "${current}" == "true" ]] && printf 'y' || printf 'n')"
    read -r value
    value="${value:-${current}}"
    if normalized="$(normalize_bool "${value}")"; then
      printf '%s\n' "${normalized}"
      return
    fi
    warn "Please enter yes or no."
  done
}

prompt_source() {
  current="$1"
  choice=""
  echo "Choose wallpaper source:"
  echo "  1) bing - Bing daily wallpaper"
  echo "  2) nasa - NASA Astronomy Picture of the Day"
  echo "  3) esa  - ESA Images"
  while true; do
    printf 'Source [current: %s]: ' "${current}"
    read -r choice
    case "${choice:-${current}}" in
      1|bing) printf 'bing\n'; return ;;
      2|nasa|apod) printf 'nasa\n'; return ;;
      3|esa) printf 'esa\n'; return ;;
      *) warn "Choose 1, 2, 3, bing, nasa, or esa." ;;
    esac
  done
}

configure_plain_tui() {
  load_config
  clear 2>/dev/null || true
  echo "${APP_NAME} configuration"
  echo "================================"
  echo

  ENABLED="$(prompt_bool 'Enable automatic wallpaper updates?' "${ENABLED}")"
  UPDATE_INTERVAL="$(prompt_value 'Update interval (examples: 30min, 12h, 1d, 1w)' "${UPDATE_INTERVAL}")"
  while ! validate_interval "${UPDATE_INTERVAL}"; do
    warn "Invalid interval. Use values like 30min, 12h, 1d, or 1w."
    UPDATE_INTERVAL="$(prompt_value 'Update interval' "${DEFAULT_UPDATE_INTERVAL}")"
  done
  ON_BOOT_DELAY="$(prompt_value 'Delay after login before first run' "${ON_BOOT_DELAY}")"
  while ! validate_interval "${ON_BOOT_DELAY}"; do
    warn "Invalid boot delay. Use values like 30s, 2min, or 1h."
    ON_BOOT_DELAY="$(prompt_value 'Delay after login before first run' "${DEFAULT_ON_BOOT_DELAY}")"
  done
  SOURCE="$(prompt_source "${SOURCE}")"
  TARGET_DIR="$(prompt_value 'Wallpaper directory' "${TARGET_DIR}")"
  TARGET_FILE="$(prompt_value 'Exact wallpaper file (blank for source-specific default)' "${TARGET_FILE}")"

  case "${SOURCE}" in
    bing)
      BING_MARKET_VALUE="$(prompt_value 'Bing market' "${BING_MARKET_VALUE}")"
      BING_RESOLUTION_VALUE="$(prompt_value 'Bing resolution' "${BING_RESOLUTION_VALUE}")"
      ;;
    nasa|apod)
      NASA_API_KEY_VALUE="$(prompt_value 'NASA API key' "${NASA_API_KEY_VALUE}")"
      NASA_APOD_FALLBACK_COUNT_VALUE="$(prompt_value 'NASA fallback random image count' "${NASA_APOD_FALLBACK_COUNT_VALUE}")"
      ;;
    esa)
      ESA_IMAGES_URL_VALUE="$(prompt_value 'ESA Images listing URL' "${ESA_IMAGES_URL_VALUE}")"
      ;;
  esac

  echo
  apply_schedule
  echo
  print_status
}

configure_whiptail_tui() {
  load_config
  new_enabled="false"
  if whiptail --title "${APP_NAME}" --yesno "Enable automatic wallpaper updates?" 8 60; then
    new_enabled="true"
  fi

  new_source="$(whiptail --title "${APP_NAME}" --menu "Choose wallpaper source" 15 70 3 \
    bing "Bing daily wallpaper" \
    nasa "NASA Astronomy Picture of the Day" \
    esa "ESA Images" \
    3>&1 1>&2 2>&3)"

  new_interval="$(whiptail --title "${APP_NAME}" --inputbox "Update interval (examples: 30min, 12h, 1d, 1w)" 8 70 "${UPDATE_INTERVAL}" 3>&1 1>&2 2>&3)"
  new_boot_delay="$(whiptail --title "${APP_NAME}" --inputbox "Delay after login before first run" 8 70 "${ON_BOOT_DELAY}" 3>&1 1>&2 2>&3)"
  new_target_dir="$(whiptail --title "${APP_NAME}" --inputbox "Wallpaper directory" 8 70 "${TARGET_DIR}" 3>&1 1>&2 2>&3)"
  new_target_file="$(whiptail --title "${APP_NAME}" --inputbox "Exact wallpaper file (blank for source-specific default)" 8 70 "${TARGET_FILE}" 3>&1 1>&2 2>&3)"

  ENABLED="${new_enabled}"
  SOURCE="${new_source}"
  UPDATE_INTERVAL="${new_interval}"
  ON_BOOT_DELAY="${new_boot_delay}"
  TARGET_DIR="${new_target_dir}"
  TARGET_FILE="${new_target_file}"

  case "${SOURCE}" in
    bing)
      BING_MARKET_VALUE="$(whiptail --title "Bing" --inputbox "Bing market" 8 70 "${BING_MARKET_VALUE}" 3>&1 1>&2 2>&3)"
      BING_RESOLUTION_VALUE="$(whiptail --title "Bing" --inputbox "Bing resolution" 8 70 "${BING_RESOLUTION_VALUE}" 3>&1 1>&2 2>&3)"
      ;;
    nasa|apod)
      NASA_API_KEY_VALUE="$(whiptail --title "NASA APOD" --inputbox "NASA API key" 8 70 "${NASA_API_KEY_VALUE}" 3>&1 1>&2 2>&3)"
      NASA_APOD_FALLBACK_COUNT_VALUE="$(whiptail --title "NASA APOD" --inputbox "Fallback random image count" 8 70 "${NASA_APOD_FALLBACK_COUNT_VALUE}" 3>&1 1>&2 2>&3)"
      ;;
    esa)
      ESA_IMAGES_URL_VALUE="$(whiptail --title "ESA Images" --inputbox "ESA Images listing URL" 8 80 "${ESA_IMAGES_URL_VALUE}" 3>&1 1>&2 2>&3)"
      ;;
  esac

  apply_schedule
  whiptail --title "${APP_NAME}" --msgbox "Configuration saved." 8 50
}

configure_tui() {
  if command -v whiptail >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
    configure_whiptail_tui
  else
    configure_plain_tui
  fi
}

run_update() {
  load_config
  validate_config
  select_wallpaper_source
  download_wallpaper
}

set_config_value() {
  key="$1"
  value="$2"
  load_config
  case "${key}" in
    enabled) ENABLED="$(normalize_bool "${value}")" || { error "enabled must be true or false."; exit 1; } ;;
    source) SOURCE="${value}" ;;
    interval|update-interval) UPDATE_INTERVAL="${value}" ;;
    boot-delay) ON_BOOT_DELAY="${value}" ;;
    target-dir) TARGET_DIR="${value}" ;;
    target-file) TARGET_FILE="${value}" ;;
    bing-market) BING_MARKET_VALUE="${value}" ;;
    bing-resolution) BING_RESOLUTION_VALUE="${value}" ;;
    nasa-api-key) NASA_API_KEY_VALUE="${value}" ;;
    nasa-fallback-count) NASA_APOD_FALLBACK_COUNT_VALUE="${value}" ;;
    esa-images-url) ESA_IMAGES_URL_VALUE="${value}" ;;
    *) error "Unknown config key '${key}'."; exit 1 ;;
  esac
  apply_schedule
}

usage() {
  cat <<USAGE
Usage: ${APP_NAME} <command> [options]

Commands:
  configure              Open the interactive configuration TUI.
  run                   Download and apply the configured wallpaper now.
  status                Show current configuration and timer state.
  enable                Enable the systemd user timer.
  disable               Disable the systemd user timer.
  set <key> <value>     Update one setting non-interactively and apply timer changes.
  install-systemd       Write/update systemd user units from the saved configuration.
  help                  Show this help.

Common set keys:
  enabled, source, interval, boot-delay, target-dir, target-file,
  bing-market, bing-resolution, nasa-api-key, nasa-fallback-count, esa-images-url
USAGE
}

main() {
  command="${1:-configure}"
  shift || true

  case "${command}" in
    configure|config) configure_tui ;;
    run|update|now) run_update ;;
    status) print_status ;;
    enable)
      load_config
      ENABLED="true"
      apply_schedule
      ;;
    disable)
      load_config
      ENABLED="false"
      apply_schedule
      ;;
    set)
      if [[ "$#" -ne 2 ]]; then
        error "set requires <key> <value>."
        usage
        exit 1
      fi
      set_config_value "$1" "$2"
      ;;
    install-systemd)
      load_config
      apply_schedule
      ;;
    help|-h|--help) usage ;;
    *)
      error "Unknown command '${command}'."
      usage
      exit 1
      ;;
  esac
}

main "$@"
