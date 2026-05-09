#!/usr/bin/env bash
set -euo pipefail

MARKET="${BING_MARKET:-de-DE}"
RESOLUTION="${BING_RESOLUTION:-UHD}"
API_URL="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=${MARKET}"
TARGET_DIR="${HOME}/Pictures"
TARGET_FILE="${TARGET_DIR}/bing-wallpaper.jpg"
CURL_USER_AGENT="${BING_USER_AGENT:-Mozilla/5.0 (X11; Linux x86_64) gnome-bing-wallpaper}"

IMAGE_JSON="$(curl -fsSL -A "${CURL_USER_AGENT}" "${API_URL}" | jq -e '.images[0]')"
URL_PATH="$(jq -r '.url // empty' <<<"${IMAGE_JSON}")"
URL_BASE="$(jq -r '.urlbase // empty' <<<"${IMAGE_JSON}")"

if [[ -z "${URL_PATH}" || "${URL_PATH}" == "null" ]]; then
  echo "Error: Bing API did not return a wallpaper URL for market ${MARKET}." >&2
  exit 1
fi

if [[ -n "${URL_BASE}" && "${URL_BASE}" != "null" ]]; then
  FULL_URL="https://www.bing.com${URL_BASE}_${RESOLUTION}.jpg"
else
  FULL_URL="https://www.bing.com${URL_PATH}"
fi

mkdir -p "${TARGET_DIR}"
TEMP_FILE="$(mktemp "${TARGET_DIR}/bing-wallpaper.XXXXXX")"
cleanup() {
  rm -f "${TEMP_FILE}"
}
trap cleanup EXIT

if ! curl -fsSL -A "${CURL_USER_AGENT}" -o "${TEMP_FILE}" "${FULL_URL}"; then
  FALLBACK_URL="https://www.bing.com${URL_PATH}"
  if [[ "${FULL_URL}" == "${FALLBACK_URL}" ]]; then
    echo "Error: Failed to download Bing wallpaper from ${FULL_URL}." >&2
    exit 1
  fi

  echo "Warning: Could not download ${RESOLUTION} wallpaper; falling back to Bing default image." >&2
  curl -fsSL -A "${CURL_USER_AGENT}" -o "${TEMP_FILE}" "${FALLBACK_URL}"
  FULL_URL="${FALLBACK_URL}"
fi

mv "${TEMP_FILE}" "${TARGET_FILE}"
trap - EXIT

gsettings set org.gnome.desktop.background picture-uri "file://${TARGET_FILE}"
gsettings set org.gnome.desktop.background picture-uri-dark "file://${TARGET_FILE}"

echo "Wallpaper updated: ${TARGET_FILE}"
echo "Source: ${FULL_URL}"
