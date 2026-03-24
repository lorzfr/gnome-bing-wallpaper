#!/usr/bin/env bash
set -euo pipefail

MARKET="${BING_MARKET:-de-DE}"
API_URL="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=${MARKET}"
TARGET_DIR="${HOME}/Pictures"
TARGET_FILE="${TARGET_DIR}/bing-wallpaper.jpg"

URL_PATH="$(curl -fsSL "${API_URL}" | jq -r '.images[0].url')"
if [[ -z "${URL_PATH}" || "${URL_PATH}" == "null" ]]; then
  echo "Error: Bing API did not return a wallpaper URL for market ${MARKET}." >&2
  exit 1
fi

FULL_URL="https://www.bing.com${URL_PATH}"
mkdir -p "${TARGET_DIR}"
curl -fsSL -o "${TARGET_FILE}" "${FULL_URL}"

gsettings set org.gnome.desktop.background picture-uri "file://${TARGET_FILE}"
gsettings set org.gnome.desktop.background picture-uri-dark "file://${TARGET_FILE}"

echo "Wallpaper updated: ${TARGET_FILE}"
#!/bin/bash

URL=$(curl -s "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=de-DE" | jq -r '.images[0].url')
FULL_URL="https://www.bing.com$URL"

mkdir -p ~/Pictures
curl -o ~/Pictures/bing-wallpaper.jpg "$FULL_URL"

gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/bing-wallpaper.jpg"
gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/Pictures/bing-wallpaper.jpg"
