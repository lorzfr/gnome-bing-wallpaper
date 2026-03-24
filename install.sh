#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="gnome-bing-wallpaper"
INSTALL_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
TARGET_SCRIPT="${INSTALL_DIR}/${SERVICE_NAME}"
SOURCE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bing-wallpaper.sh"

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m   $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERR]\033[0m  $*" >&2; }

check_os() {
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS (/etc/os-release missing)."
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  local id_like="${ID_LIKE:-}"
  if [[ "${ID}" != "debian" && "${ID}" != "zorin" && "${id_like}" != *"debian"* ]]; then
    error "This installer targets Debian-based systems (recommended: Zorin OS 18)."
    exit 1
  fi

  if [[ "${ID}" == "zorin" && "${VERSION_ID:-}" != "18" ]]; then
    warn "Detected Zorin OS ${VERSION_ID:-unknown}. This is tuned for Zorin OS 18, but will continue."
  fi

  success "Detected OS: ${PRETTY_NAME:-unknown}"
}

check_gnome() {
  if ! command -v gsettings >/dev/null 2>&1; then
    error "gsettings is not available. Please install GNOME desktop components first."
    exit 1
  fi

  if [[ ! -d /usr/share/gnome-shell ]] && ! command -v gnome-shell >/dev/null 2>&1; then
    error "GNOME does not appear to be installed."
    exit 1
  fi

  success "GNOME desktop tooling detected."
}

install_dependencies() {
  local missing=()
  for cmd in curl jq systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    success "Required commands already available."
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    error "Missing required commands: ${missing[*]} and sudo is unavailable for installation."
    exit 1
  fi

  info "Installing missing dependencies: ${missing[*]}"
  sudo apt-get update
  sudo apt-get install -y curl jq systemd
  success "Dependencies installed."
}

install_script() {
  mkdir -p "${INSTALL_DIR}"
  install -m 0755 "${SOURCE_SCRIPT}" "${TARGET_SCRIPT}"
  success "Installed wallpaper script to ${TARGET_SCRIPT}"
}

install_systemd_units() {
  mkdir -p "${SYSTEMD_USER_DIR}"

  cat > "${SYSTEMD_USER_DIR}/${SERVICE_NAME}.service" <<UNIT
[Unit]
Description=Set GNOME wallpaper from Bing
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/${SERVICE_NAME}
UNIT

  cat > "${SYSTEMD_USER_DIR}/${SERVICE_NAME}.timer" <<UNIT
[Unit]
Description=Run Bing wallpaper updater daily

[Timer]
OnBootSec=2min
OnUnitActiveSec=24h
Persistent=true

[Install]
WantedBy=timers.target
UNIT

  systemctl --user daemon-reload
  systemctl --user enable --now "${SERVICE_NAME}.timer"
  systemctl --user start "${SERVICE_NAME}.service"

  success "Systemd user service and timer installed."
}

main() {
  info "Installing GNOME Bing Wallpaper service..."
  check_os
  check_gnome
  install_dependencies
  install_script
  install_systemd_units

  echo
  success "All done 🎉"
  echo "- Timer status: systemctl --user status ${SERVICE_NAME}.timer"
  echo "- Last run logs: journalctl --user -u ${SERVICE_NAME}.service -n 50 --no-pager"
  echo "- Re-run now: systemctl --user start ${SERVICE_NAME}.service"
}

main "$@"
