# gnome-bing-wallpaper

A simple headless setup for downloading a daily wallpaper and applying it to GNOME. It supports Bing by default, plus optional space-image sources from NASA APOD and ESA Images.

## Quick install (recommended)

This project includes an installer for **Zorin OS 18 (Debian-based)** that sets up a **systemd user service + timer**.

```bash
./install.sh
```

To install the timer with a non-default source, pass the source when you run the installer. The installer writes supported provider variables into the systemd user service:

```bash
WALLPAPER_SOURCE=nasa NASA_API_KEY="your_api_key_here" ./install.sh
WALLPAPER_SOURCE=esa ./install.sh
```

Or run it directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/lorzfr/gnome-bing-wallpaper/main/install.sh | sh
```

```bash
wget -qO- https://raw.githubusercontent.com/lorzfr/gnome-bing-wallpaper/main/install.sh | sh
```

What `install.sh` does:

- verifies the OS is Debian-based (recommended target: Zorin OS 18),
- verifies GNOME is installed,
- installs missing dependencies (`curl`, `jq`, `systemd`) when needed,
- installs the updater script to `~/.local/bin/gnome-bing-wallpaper`,
- creates and enables:
  - `~/.config/systemd/user/gnome-bing-wallpaper.service`
  - `~/.config/systemd/user/gnome-bing-wallpaper.timer`

The timer runs at boot (after 2 minutes) and then every 24 hours.

## Manual run

Run the script directly:

```bash
./bing-wallpaper.sh
```

By default, the script uses Bing. Choose another source with `WALLPAPER_SOURCE`:

```bash
WALLPAPER_SOURCE=bing ./bing-wallpaper.sh
WALLPAPER_SOURCE=nasa ./bing-wallpaper.sh
WALLPAPER_SOURCE=esa ./bing-wallpaper.sh
```

Supported sources:

- `bing` - Bing's daily wallpaper.
- `nasa` or `apod` - NASA Astronomy Picture of the Day (APOD). If today's APOD is a video, the script asks APOD for random recent image entries and uses the first image returned.
- `esa` - the latest ESA Images listing entry. ESA may block some scripted requests; if that happens, run again later or use `bing`/`nasa`.

### Common options

Save to a different directory or exact file path:

```bash
WALLPAPER_TARGET_DIR="$HOME/Pictures/Wallpapers" ./bing-wallpaper.sh
WALLPAPER_TARGET_FILE="$HOME/Pictures/current-wallpaper.jpg" ./bing-wallpaper.sh
```

Override the HTTP user agent used for all providers:

```bash
WALLPAPER_USER_AGENT="Mozilla/5.0 my-wallpaper-script" ./bing-wallpaper.sh
```

### Bing options

You can override the Bing market with `BING_MARKET`:

```bash
BING_MARKET=en-US ./bing-wallpaper.sh
```

By default the script downloads Bing's UHD image when available. You can request another Bing image size with `BING_RESOLUTION` (for example `1920x1080`):

```bash
BING_RESOLUTION=1920x1080 ./bing-wallpaper.sh
```

### NASA APOD options

NASA APOD works with the public `DEMO_KEY` by default, but NASA rate-limits that shared key. For regular daily use, get your own key from NASA and pass it as `NASA_API_KEY`:

```bash
WALLPAPER_SOURCE=nasa NASA_API_KEY="your_api_key_here" ./bing-wallpaper.sh
```

When today's APOD is not an image, the script requests random APOD entries and selects the first image. Change the request size with `NASA_APOD_FALLBACK_COUNT`:

```bash
WALLPAPER_SOURCE=nasa NASA_APOD_FALLBACK_COUNT=20 ./bing-wallpaper.sh
```

### ESA options

The ESA source scrapes the public ESA Images listing and then uses the selected image page's Open Graph image URL. You can point it at another ESA Images listing page with `ESA_IMAGES_URL`:

```bash
WALLPAPER_SOURCE=esa ESA_IMAGES_URL="https://www.esa.int/ESA_Multimedia/Images/2026/04" ./bing-wallpaper.sh
```

## Requirements

- GNOME desktop (`gsettings`, `gnome-shell`)
- `bash`
- `curl`
- `jq`
- `systemd` (for automated daily updates)
