#!/usr/bin/env bash
set -euo pipefail

APP_NAME="bingwallpaper"
SERVICE_NAME="bingwallpaper"
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/${APP_NAME}"
CONFIG_FILE="${CONFIG_DIR}/config"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
SERVICE_FILE="${SYSTEMD_USER_DIR}/${SERVICE_NAME}.service"
TIMER_FILE="${SYSTEMD_USER_DIR}/${SERVICE_NAME}.timer"
INSTALL_PATH="${HOME}/.local/bin/${APP_NAME}"

DEFAULT_ENABLED="yes"
DEFAULT_CHECK_INTERVAL="24h"
DEFAULT_WALLPAPER_SOURCE="bing"
DEFAULT_BING_MARKET="de-DE"
DEFAULT_BING_RESOLUTION="UHD"
DEFAULT_NASA_API_KEY="DEMO_KEY"
DEFAULT_NASA_APOD_FALLBACK_COUNT="10"
DEFAULT_ESA_IMAGES_URL="https://www.esa.int/ESA_Multimedia/Images"
DEFAULT_WALLPAPER_TARGET_DIR="${HOME}/Pictures"
DEFAULT_WALLPAPER_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) ${APP_NAME}"

FULL_URL=""
SOURCE_LABEL=""
SOURCE_TITLE=""
BING_FALLBACK_URL=""

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[ERR]\033[0m  %s\n' "$*" >&2; }

ensure_config_dir() {
  mkdir -p "${CONFIG_DIR}"
}

write_default_config() {
  ensure_config_dir
  if [[ -f "${CONFIG_FILE}" ]]; then
    return
  fi

  cat > "${CONFIG_FILE}" <<EOF_CONFIG
# ${APP_NAME} settings
# Edit this file manually or run: ${APP_NAME}
ENABLED="${DEFAULT_ENABLED}"
CHECK_INTERVAL="${DEFAULT_CHECK_INTERVAL}"
WALLPAPER_SOURCE="${DEFAULT_WALLPAPER_SOURCE}"
WALLPAPER_TARGET_DIR="${DEFAULT_WALLPAPER_TARGET_DIR}"
WALLPAPER_USER_AGENT="${DEFAULT_WALLPAPER_USER_AGENT}"
BING_MARKET="${DEFAULT_BING_MARKET}"
BING_RESOLUTION="${DEFAULT_BING_RESOLUTION}"
NASA_API_KEY="${DEFAULT_NASA_API_KEY}"
NASA_APOD_FALLBACK_COUNT="${DEFAULT_NASA_APOD_FALLBACK_COUNT}"
ESA_IMAGES_URL="${DEFAULT_ESA_IMAGES_URL}"
EOF_CONFIG
}

load_config() {
  write_default_config
  # shellcheck disable=SC1090
  . "${CONFIG_FILE}"

  ENABLED="${ENABLED:-${DEFAULT_ENABLED}}"
  CHECK_INTERVAL="${CHECK_INTERVAL:-${DEFAULT_CHECK_INTERVAL}}"
  WALLPAPER_SOURCE="${WALLPAPER_SOURCE:-${DEFAULT_WALLPAPER_SOURCE}}"
  WALLPAPER_TARGET_DIR="${WALLPAPER_TARGET_DIR:-${DEFAULT_WALLPAPER_TARGET_DIR}}"
  WALLPAPER_USER_AGENT="${WALLPAPER_USER_AGENT:-${DEFAULT_WALLPAPER_USER_AGENT}}"
  BING_MARKET="${BING_MARKET:-${DEFAULT_BING_MARKET}}"
  BING_RESOLUTION="${BING_RESOLUTION:-${DEFAULT_BING_RESOLUTION}}"
  NASA_API_KEY="${NASA_API_KEY:-${DEFAULT_NASA_API_KEY}}"
  NASA_APOD_FALLBACK_COUNT="${NASA_APOD_FALLBACK_COUNT:-${DEFAULT_NASA_APOD_FALLBACK_COUNT}}"
  ESA_IMAGES_URL="${ESA_IMAGES_URL:-${DEFAULT_ESA_IMAGES_URL}}"
}

write_config_entry() {
  printf '%s=' "$1"
  printf '%q' "$2"
  printf '\n'
}

save_config() {
  ensure_config_dir
  {
    printf '# %s settings\n' "${APP_NAME}"
    printf '# Edit this file manually or run: %s\n' "${APP_NAME}"
    write_config_entry ENABLED "${ENABLED}"
    write_config_entry CHECK_INTERVAL "${CHECK_INTERVAL}"
    write_config_entry WALLPAPER_SOURCE "${WALLPAPER_SOURCE}"
    write_config_entry WALLPAPER_TARGET_DIR "${WALLPAPER_TARGET_DIR}"
    write_config_entry WALLPAPER_USER_AGENT "${WALLPAPER_USER_AGENT}"
    write_config_entry BING_MARKET "${BING_MARKET}"
    write_config_entry BING_RESOLUTION "${BING_RESOLUTION}"
    write_config_entry NASA_API_KEY "${NASA_API_KEY}"
    write_config_entry NASA_APOD_FALLBACK_COUNT "${NASA_APOD_FALLBACK_COUNT}"
    write_config_entry ESA_IMAGES_URL "${ESA_IMAGES_URL}"
  } > "${CONFIG_FILE}"
}

write_systemd_units() {
  load_config
  mkdir -p "${SYSTEMD_USER_DIR}"

  cat > "${SERVICE_FILE}" <<EOF_SERVICE
[Unit]
Description=Set GNOME wallpaper from the configured ${APP_NAME} source
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/${APP_NAME} --update
EOF_SERVICE

  cat > "${TIMER_FILE}" <<EOF_TIMER
[Unit]
Description=Run ${APP_NAME} wallpaper checks

[Timer]
OnBootSec=2min
OnUnitActiveSec=${CHECK_INTERVAL}
Persistent=true

[Install]
WantedBy=timers.target
EOF_TIMER

  systemctl --user daemon-reload
}

apply_timer_state() {
  load_config
  write_systemd_units

  if [[ "${ENABLED}" == "yes" ]]; then
    systemctl --user enable --now "${SERVICE_NAME}.timer"
    success "Automatic wallpaper checks enabled (${CHECK_INTERVAL})."
  else
    systemctl --user disable --now "${SERVICE_NAME}.timer" >/dev/null 2>&1 || true
    success "Automatic wallpaper checks disabled."
  fi
}

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

fetch_bing_metadata() {
  local api_url image_json url_path url_base
  api_url="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=${BING_MARKET}"

  image_json="$(curl -fsSL -A "${WALLPAPER_USER_AGENT}" "${api_url}" | jq -e '.images[0]')"
  url_path="$(jq -r '.url // empty' <<<"${image_json}")"
  url_base="$(jq -r '.urlbase // empty' <<<"${image_json}")"
  SOURCE_TITLE="$(jq -r '.title // .copyright // "Bing daily wallpaper"' <<<"${image_json}")"

  if [[ -z "${url_path}" || "${url_path}" == "null" ]]; then
    error "Bing API did not return a wallpaper URL for market ${BING_MARKET}."
    exit 1
  fi

  if [[ -n "${url_base}" && "${url_base}" != "null" ]]; then
    FULL_URL="https://www.bing.com${url_base}_${BING_RESOLUTION}.jpg"
  else
    FULL_URL="https://www.bing.com${url_path}"
  fi

  BING_FALLBACK_URL="https://www.bing.com${url_path}"
  SOURCE_LABEL="Bing"
}

fetch_nasa_metadata() {
  local api_url image_json media_type
  api_url="https://api.nasa.gov/planetary/apod?api_key=${NASA_API_KEY}"

  image_json="$(curl -fsSL -A "${WALLPAPER_USER_AGENT}" "${api_url}" | jq -e '.')"
  media_type="$(jq -r '.media_type // empty' <<<"${image_json}")"

  if [[ "${media_type}" != "image" ]]; then
    image_json="$(curl -fsSL -A "${WALLPAPER_USER_AGENT}" "https://api.nasa.gov/planetary/apod?api_key=${NASA_API_KEY}&count=${NASA_APOD_FALLBACK_COUNT}" | jq -e '[.[] | select(.media_type == "image")][0]')"
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
  local index_html image_page page_html
  index_html="$(curl -fsSL -A "${WALLPAPER_USER_AGENT}" "${ESA_IMAGES_URL}")"

  image_page="$(printf '%s' "${index_html}" \
    | sed -nE 's/.*href="([^"]*\/ESA_Multimedia\/Images\/[0-9]{4}\/[0-9]{2}\/[^"]+)".*/\1/p' \
    | head -n 1 \
    | html_unescape)"

  if [[ -z "${image_page}" ]]; then
    error "ESA image listing did not contain an image page link."
    exit 1
  fi

  image_page="$(absolute_url "${image_page}" "https://www.esa.int")"
  page_html="$(curl -fsSL -A "${WALLPAPER_USER_AGENT}" "${image_page}")"

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
  case "${WALLPAPER_SOURCE}" in
    bing) fetch_bing_metadata ;;
    nasa|apod) fetch_nasa_metadata ;;
    esa) fetch_esa_metadata ;;
    *)
      error "Unsupported source '${WALLPAPER_SOURCE}'. Use one of: bing, nasa, esa."
      exit 1
      ;;
  esac
}

download_wallpaper() {
  local target_file temp_file
  mkdir -p "${WALLPAPER_TARGET_DIR}"
  target_file="${WALLPAPER_TARGET_FILE:-${WALLPAPER_TARGET_DIR}/${WALLPAPER_SOURCE}-wallpaper.jpg}"
  temp_file="$(mktemp "${WALLPAPER_TARGET_DIR}/${WALLPAPER_SOURCE}-wallpaper.XXXXXX")"
  cleanup() {
    rm -f "${temp_file}"
  }
  trap cleanup EXIT

  if ! curl -fsSL -A "${WALLPAPER_USER_AGENT}" -o "${temp_file}" "${FULL_URL}"; then
    if [[ "${WALLPAPER_SOURCE}" == "bing" && "${FULL_URL}" != "${BING_FALLBACK_URL}" ]]; then
      warn "Could not download ${BING_RESOLUTION}; falling back to Bing default image."
      curl -fsSL -A "${WALLPAPER_USER_AGENT}" -o "${temp_file}" "${BING_FALLBACK_URL}"
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
  info "Source (${SOURCE_LABEL}): ${FULL_URL}"
  if [[ -n "${SOURCE_TITLE}" ]]; then
    info "Title: ${SOURCE_TITLE}"
  fi
}

update_wallpaper() {
  load_config
  select_wallpaper_source
  download_wallpaper
}

print_status() {
  load_config
  printf '\n%s status\n' "${APP_NAME}"
  printf '====================\n'
  printf 'Enabled:        %s\n' "${ENABLED}"
  printf 'Check interval: %s\n' "${CHECK_INTERVAL}"
  printf 'Source:         %s\n' "${WALLPAPER_SOURCE}"
  printf 'Config file:    %s\n' "${CONFIG_FILE}"
  printf 'Timer:          %s\n' "${TIMER_FILE}"
  printf '\n'
}

prompt_value() {
  local label current value
  label="$1"
  current="$2"
  printf '%s [%s]: ' "${label}" "${current}"
  read -r value
  if [[ -n "${value}" ]]; then
    printf '%s' "${value}"
  else
    printf '%s' "${current}"
  fi
}

configure_enabled() {
  local answer
  printf 'Enable automatic wallpaper checks? (y/n) [%s]: ' "${ENABLED}"
  read -r answer
  case "${answer}" in
    y|Y|yes|YES) ENABLED="yes" ;;
    n|N|no|NO) ENABLED="no" ;;
    "") ;;
    *) warn "Keeping current value: ${ENABLED}" ;;
  esac
}

configure_interval() {
  local choice custom
  printf '\nChoose how often %s checks for a new wallpaper:\n' "${APP_NAME}"
  printf '  1) Every hour\n'
  printf '  2) Every 6 hours\n'
  printf '  3) Every 12 hours\n'
  printf '  4) Daily (24 hours)\n'
  printf '  5) Weekly\n'
  printf '  6) Custom systemd interval (example: 30min, 8h, 2d)\n'
  printf 'Current: %s\n' "${CHECK_INTERVAL}"
  printf 'Select [1-6]: '
  read -r choice

  case "${choice}" in
    1) CHECK_INTERVAL="1h" ;;
    2) CHECK_INTERVAL="6h" ;;
    3) CHECK_INTERVAL="12h" ;;
    4) CHECK_INTERVAL="24h" ;;
    5) CHECK_INTERVAL="7d" ;;
    6)
      custom="$(prompt_value 'Custom interval' "${CHECK_INTERVAL}")"
      CHECK_INTERVAL="${custom}"
      ;;
    "") ;;
    *) warn "Keeping current interval: ${CHECK_INTERVAL}" ;;
  esac
}

configure_source() {
  local choice
  printf '\nChoose wallpaper source:\n'
  printf '  1) Bing daily wallpaper\n'
  printf '  2) NASA Astronomy Picture of the Day\n'
  printf '  3) ESA Images\n'
  printf 'Current: %s\n' "${WALLPAPER_SOURCE}"
  printf 'Select [1-3]: '
  read -r choice

  case "${choice}" in
    1) WALLPAPER_SOURCE="bing" ;;
    2) WALLPAPER_SOURCE="nasa" ;;
    3) WALLPAPER_SOURCE="esa" ;;
    "") ;;
    *) warn "Keeping current source: ${WALLPAPER_SOURCE}" ;;
  esac

  case "${WALLPAPER_SOURCE}" in
    bing)
      BING_MARKET="$(prompt_value 'Bing market' "${BING_MARKET}")"
      BING_RESOLUTION="$(prompt_value 'Bing resolution' "${BING_RESOLUTION}")"
      ;;
    nasa|apod)
      NASA_API_KEY="$(prompt_value 'NASA API key' "${NASA_API_KEY}")"
      NASA_APOD_FALLBACK_COUNT="$(prompt_value 'NASA fallback image count' "${NASA_APOD_FALLBACK_COUNT}")"
      ;;
    esa)
      ESA_IMAGES_URL="$(prompt_value 'ESA Images URL' "${ESA_IMAGES_URL}")"
      ;;
  esac
}

configure_target_dir() {
  WALLPAPER_TARGET_DIR="$(prompt_value 'Wallpaper save directory' "${WALLPAPER_TARGET_DIR}")"
}

run_tui() {
  load_config
  while true; do
    print_status
    printf 'What would you like to do?\n'
    printf '  1) Enable/disable automatic updates\n'
    printf '  2) Change update/check interval\n'
    printf '  3) Change wallpaper source\n'
    printf '  4) Change save directory\n'
    printf '  5) Save settings and apply systemd timer\n'
    printf '  6) Update wallpaper now\n'
    printf '  7) Quit\n'
    printf 'Select [1-7]: '
    read -r choice

    case "${choice}" in
      1) configure_enabled; save_config ;;
      2) configure_interval; save_config ;;
      3) configure_source; save_config ;;
      4) configure_target_dir; save_config ;;
      5) save_config; apply_timer_state ;;
      6) save_config; update_wallpaper ;;
      7|q|Q) break ;;
      *) warn "Unknown choice." ;;
    esac
  done
}

print_help() {
  cat <<EOF_HELP
${APP_NAME} - GNOME wallpaper updater

Usage:
  ${APP_NAME}              Open the configuration TUI
  ${APP_NAME} --update     Download and apply the configured wallpaper now
  ${APP_NAME} --status     Show current settings
  ${APP_NAME} --apply      Recreate and enable/disable the systemd user timer
  ${APP_NAME} --help       Show this help
EOF_HELP
}

case "${1:-}" in
  "") run_tui ;;
  --update|update) update_wallpaper ;;
  --status|status) print_status ;;
  --apply|apply) apply_timer_state ;;
  --help|-h|help) print_help ;;
  *)
    error "Unknown option: $1"
    print_help
    exit 2
    ;;
esac
