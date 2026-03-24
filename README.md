# gnome-bing-wallpaper

A simple headless setup for downloading Bing's daily wallpaper and applying it to GNOME.

## Quick install (recommended)

This project includes an installer for **Zorin OS 18 (Debian-based)** that sets up a **systemd user service + timer**.

```bash
./install.sh
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
A basic headless script that pulls the daily wallpaper from Bing and sets it as the GNOME wallpaper.

## Script

Run:

```bash
./bing-wallpaper.sh
```

You can override the Bing market with `BING_MARKET`:

```bash
BING_MARKET=en-US ./bing-wallpaper.sh
```

## Requirements

- GNOME desktop (`gsettings`, `gnome-shell`)
- `bash`
- `curl`
- `jq`
- `systemd` (for automated daily updates)
The script:

- fetches Bing's daily wallpaper metadata for the `de-DE` market,
- downloads the image to `~/Pictures/bing-wallpaper.jpg`,
- sets both `picture-uri` and `picture-uri-dark` in GNOME.

## Requirements

- `bash`
- `curl`
- `jq`
- `gsettings` (GNOME)
