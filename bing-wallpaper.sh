#!/usr/bin/env bash
set -euo pipefail

SOURCE="${WALLPAPER_SOURCE:-bing}"
TARGET_DIR="${WALLPAPER_TARGET_DIR:-${HOME}/Pictures}"
CURL_USER_AGENT="${WALLPAPER_USER_AGENT:-${BING_USER_AGENT:-Mozilla/5.0 (X11; Linux x86_64) gnome-bing-wallpaper}}"
FULL_URL=""
SOURCE_LABEL=""
SOURCE_TITLE=""
BING_FALLBACK_URL=""

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
  market="${BING_MARKET:-de-DE}"
  resolution="${BING_RESOLUTION:-UHD}"
  api_url="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=${market}"

  image_json="$(curl -fsSL -A "${CURL_USER_AGENT}" "${api_url}" | jq -e '.images[0]')"
  url_path="$(jq -r '.url // empty' <<<"${image_json}")"
  url_base="$(jq -r '.urlbase // empty' <<<"${image_json}")"
  SOURCE_TITLE="$(jq -r '.title // .copyright // "Bing daily wallpaper"' <<<"${image_json}")"

  if [[ -z "${url_path}" || "${url_path}" == "null" ]]; then
    echo "Error: Bing API did not return a wallpaper URL for market ${market}." >&2
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
  api_key="${NASA_API_KEY:-DEMO_KEY}"
  api_url="https://api.nasa.gov/planetary/apod?api_key=${api_key}"

  image_json="$(curl -fsSL -A "${CURL_USER_AGENT}" "${api_url}" | jq -e '.')"
  media_type="$(jq -r '.media_type // empty' <<<"${image_json}")"

  if [[ "${media_type}" != "image" ]]; then
    fallback_count="${NASA_APOD_FALLBACK_COUNT:-10}"
    image_json="$(curl -fsSL -A "${CURL_USER_AGENT}" "https://api.nasa.gov/planetary/apod?api_key=${api_key}&count=${fallback_count}" | jq -e '[.[] | select(.media_type == "image")][0]')"
  fi

  FULL_URL="$(jq -r '.hdurl // .url // empty' <<<"${image_json}")"
  SOURCE_TITLE="$(jq -r '.title // "NASA Astronomy Picture of the Day"' <<<"${image_json}")"

  if [[ -z "${FULL_URL}" || "${FULL_URL}" == "null" ]]; then
    echo "Error: NASA APOD API did not return an image URL." >&2
    exit 1
  fi

  SOURCE_LABEL="NASA APOD"
}

fetch_esa_metadata() {
  index_url="${ESA_IMAGES_URL:-https://www.esa.int/ESA_Multimedia/Images}"
  index_html="$(curl -fsSL -A "${CURL_USER_AGENT}" "${index_url}")"

  image_page="$(printf '%s' "${index_html}" \
    | sed -nE 's/.*href="([^"]*\/ESA_Multimedia\/Images\/[0-9]{4}\/[0-9]{2}\/[^"]+)".*/\1/p' \
    | head -n 1 \
    | html_unescape)"

  if [[ -z "${image_page}" ]]; then
    echo "Error: ESA image listing did not contain an image page link." >&2
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
    echo "Error: ESA image page did not contain an Open Graph image URL: ${image_page}" >&2
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
    *)
      echo "Error: Unsupported WALLPAPER_SOURCE '${SOURCE}'. Use one of: bing, nasa, esa." >&2
      exit 1
      ;;
  esac
}

download_wallpaper() {
  mkdir -p "${TARGET_DIR}"
  target_file="${WALLPAPER_TARGET_FILE:-${TARGET_DIR}/${SOURCE}-wallpaper.jpg}"
  temp_file="$(mktemp "${TARGET_DIR}/${SOURCE}-wallpaper.XXXXXX")"
  cleanup() {
    rm -f "${temp_file}"
  }
  trap cleanup EXIT

  if ! curl -fsSL -A "${CURL_USER_AGENT}" -o "${temp_file}" "${FULL_URL}"; then
    if [[ "${SOURCE}" == "bing" && "${FULL_URL}" != "${BING_FALLBACK_URL}" ]]; then
      echo "Warning: Could not download ${BING_RESOLUTION:-UHD} wallpaper; falling back to Bing default image." >&2
      curl -fsSL -A "${CURL_USER_AGENT}" -o "${temp_file}" "${BING_FALLBACK_URL}"
      FULL_URL="${BING_FALLBACK_URL}"
    else
      echo "Error: Failed to download ${SOURCE_LABEL} wallpaper from ${FULL_URL}." >&2
      exit 1
    fi
  fi

  mv "${temp_file}" "${target_file}"
  trap - EXIT

  gsettings set org.gnome.desktop.background picture-uri "file://${target_file}"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://${target_file}"

  echo "Wallpaper updated: ${target_file}"
  echo "Source (${SOURCE_LABEL}): ${FULL_URL}"
  if [[ -n "${SOURCE_TITLE}" ]]; then
    echo "Title: ${SOURCE_TITLE}"
  fi
}

select_wallpaper_source
download_wallpaper
