#!/bin/sh
set -eu

APP_NAME="bingwallpaper"
LEGACY_SERVICE_NAME="gnome-bing-wallpaper"
REPO_RAW_BASE_URL="https://raw.githubusercontent.com/lorzfr/gnome-bing-wallpaper/main"
INSTALL_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
TARGET_SCRIPT="${INSTALL_DIR}/${APP_NAME}"
SOURCE_SCRIPT=""
TEMP_SCRIPT=""

cleanup() {
  if [ -n "${TEMP_SCRIPT}" ] && [ -f "${TEMP_SCRIPT}" ]; then
    rm -f "${TEMP_SCRIPT}"
  fi
}
trap cleanup EXIT

info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
success() { printf "\033[1;32m[OK]\033[0m   %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[ERR]\033[0m  %s\n" "$*" >&2; }

check_os() {
  if [ ! -f /etc/os-release ]; then
    error "Cannot detect OS (/etc/os-release missing)."
    exit 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  id_like="${ID_LIKE:-}"
  if [ "${ID}" != "debian" ] && [ "${ID}" != "zorin" ] && ! printf '%s' "${id_like}" | grep -q "debian"; then
    error "This installer targets Debian-based GNOME systems (recommended: Zorin OS 18)."
    exit 1
  fi

  if [ "${ID}" = "zorin" ] && [ "${VERSION_ID:-}" != "18" ]; then
    warn "Detected Zorin OS ${VERSION_ID:-unknown}. This is tuned for Zorin OS 18, but will continue."
  fi

  success "Detected OS: ${PRETTY_NAME:-unknown}"
}

check_gnome() {
  if ! command -v gsettings >/dev/null 2>&1; then
    error "gsettings is not available. Please install GNOME desktop components first."
    exit 1
  fi

  if [ ! -d /usr/share/gnome-shell ] && ! command -v gnome-shell >/dev/null 2>&1; then
    error "GNOME does not appear to be installed."
    exit 1
  fi

  success "GNOME desktop tooling detected."
}

install_dependencies() {
  missing=""
  for cmd in bash curl jq systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing="${missing} ${cmd}"
    fi
  done

  if [ -z "${missing# }" ]; then
    success "Required commands already available."
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    error "Missing required commands:${missing} and sudo is unavailable for installation."
    exit 1
  fi

  info "Installing missing dependencies:${missing}"
  sudo apt-get update
  sudo apt-get install -y bash curl jq systemd
  success "Dependencies installed."
}

download_file() {
  url="$1"
  output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${output}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${output}" "${url}"
  else
    error "Either curl or wget is required to download ${APP_NAME}."
    exit 1
  fi
}

prepare_source_script() {
  local_script="$(pwd)/bing-wallpaper.sh"
  if [ -f "${local_script}" ]; then
    SOURCE_SCRIPT="${local_script}"
    success "Using local program from ${SOURCE_SCRIPT}"
    return
  fi

  TEMP_SCRIPT="$(mktemp)"
  info "Downloading ${APP_NAME} from ${REPO_RAW_BASE_URL}/bing-wallpaper.sh"
  if ! download_file "${REPO_RAW_BASE_URL}/bing-wallpaper.sh" "${TEMP_SCRIPT}"; then
    rm -f "${TEMP_SCRIPT}"
    TEMP_SCRIPT=""
    error "Failed to download ${APP_NAME} from GitHub."
    exit 1
  fi

  chmod 0755 "${TEMP_SCRIPT}"
  SOURCE_SCRIPT="${TEMP_SCRIPT}"
  success "Downloaded ${APP_NAME}."
}

install_program() {
  mkdir -p "${INSTALL_DIR}"
  install -m 0755 "${SOURCE_SCRIPT}" "${TARGET_SCRIPT}"
  success "Installed ${APP_NAME} to ${TARGET_SCRIPT}"
}

remove_legacy_units() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now "${LEGACY_SERVICE_NAME}.timer" >/dev/null 2>&1 || true
  fi
  rm -f \
    "${SYSTEMD_USER_DIR}/${LEGACY_SERVICE_NAME}.service" \
    "${SYSTEMD_USER_DIR}/${LEGACY_SERVICE_NAME}.timer" \
    "${INSTALL_DIR}/${LEGACY_SERVICE_NAME}"
}

ensure_path_hint() {
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *) warn "${INSTALL_DIR} is not in PATH. Add it or open a new terminal if your shell config already includes it." ;;
  esac
}

configure_program() {
  info "Creating the default config and systemd user timer."
  "${TARGET_SCRIPT}" --apply

  if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    info "Opening the ${APP_NAME} configuration TUI."
    "${TARGET_SCRIPT}" </dev/tty >/dev/tty
  else
    warn "No interactive terminal is available, so the TUI was not opened. Run '${APP_NAME}' later to configure it."
  fi
}

main() {
  info "Installing ${APP_NAME}..."
  check_os
  check_gnome
  install_dependencies
  prepare_source_script
  install_program
  remove_legacy_units
  configure_program
  ensure_path_hint

  echo
  success "All done 🎉"
  echo "- Open settings: ${APP_NAME}"
  echo "- Update now: ${APP_NAME} --update"
  echo "- Timer status: systemctl --user status ${APP_NAME}.timer"
  echo "- Last run logs: journalctl --user -u ${APP_NAME}.service -n 50 --no-pager"
}

main "$@"
