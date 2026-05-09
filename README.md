# bingwallpaper for GNOME

`bingwallpaper` is a small GNOME wallpaper program that downloads a fresh image, applies it as your light and dark GNOME wallpaper, and can check for new wallpapers automatically in the background.

It installs as a real user command:

```bash
bingwallpaper
```

Running that command opens a simple terminal UI (TUI) where you can choose:

- whether automatic wallpaper checks are **enabled**,
- how often the wallpaper should be checked/updated,
- which image source to use,
- where downloaded wallpapers should be saved.

## Quick install

Install with **one** of these commands:

```bash
curl -fsSL https://raw.githubusercontent.com/lorzfr/gnome-bing-wallpaper/main/install.sh | sh
```

```bash
wget -qO- https://raw.githubusercontent.com/lorzfr/gnome-bing-wallpaper/main/install.sh | sh
```

The installer will:

1. check that you are on a Debian-based GNOME system,
2. install missing requirements when possible,
3. install the program as `~/.local/bin/bingwallpaper`,
4. create a user config file at `~/.config/bingwallpaper/config`,
5. create a systemd user service and timer,
6. open the `bingwallpaper` TUI so you can choose your settings.

> If the installer says `~/.local/bin` is not in your `PATH`, open a new terminal or add `export PATH="$HOME/.local/bin:$PATH"` to your shell config.

## First use

After installation, open the TUI at any time:

```bash
bingwallpaper
```

The TUI menu lets you change the main settings without editing files by hand:

- **Enabled?** Turn automatic wallpaper checks on or off.
- **Update/check interval** Choose hourly, every 6 hours, every 12 hours, daily, weekly, or a custom systemd interval such as `30min`, `8h`, or `2d`.
- **Source** Choose `Bing`, `NASA APOD`, or `ESA Images`.
- **Save directory** Choose where downloaded wallpaper files are stored.

Choose **Save settings and apply systemd timer** after changing automatic update settings.

## Daily commands

Update the wallpaper immediately:

```bash
bingwallpaper --update
```

Show the current configuration:

```bash
bingwallpaper --status
```

Recreate and enable/disable the systemd timer from the saved configuration:

```bash
bingwallpaper --apply
```

Open help:

```bash
bingwallpaper --help
```

## Wallpaper sources

### Bing daily wallpaper

This is the default source. It downloads Bing's current daily wallpaper.

TUI settings for Bing:

- **Bing market**: region/language for the Bing image feed, for example `de-DE` or `en-US`.
- **Bing resolution**: defaults to `UHD`. You can also use a size such as `1920x1080`.

### NASA APOD

NASA APOD means NASA Astronomy Picture of the Day.

TUI settings for NASA:

- **NASA API key**: defaults to NASA's shared `DEMO_KEY`.
- **NASA fallback image count**: if today's APOD is a video, `bingwallpaper` asks NASA for random APOD entries and uses the first image it finds.

For regular use, you should get your own NASA API key because `DEMO_KEY` is rate-limited.

### ESA Images

ESA Images uses the latest entry from the public ESA Images page.

TUI setting for ESA:

- **ESA Images URL**: defaults to `https://www.esa.int/ESA_Multimedia/Images`.

ESA can sometimes block scripted requests. If that happens, try again later or switch to Bing or NASA in the TUI.

## Automatic updates

`bingwallpaper` uses a systemd **user** timer, not a root system service.

Installed files:

```text
~/.local/bin/bingwallpaper
~/.config/bingwallpaper/config
~/.config/systemd/user/bingwallpaper.service
~/.config/systemd/user/bingwallpaper.timer
```

Useful timer commands:

```bash
systemctl --user status bingwallpaper.timer
```

```bash
journalctl --user -u bingwallpaper.service -n 50 --no-pager
```

```bash
systemctl --user start bingwallpaper.service
```

You normally do not need these commands because the TUI manages the timer for you.

## Manual configuration

Advanced users can edit the config file directly:

```bash
nano ~/.config/bingwallpaper/config
```

Example config:

```bash
ENABLED="yes"
CHECK_INTERVAL="24h"
WALLPAPER_SOURCE="bing"
WALLPAPER_TARGET_DIR="$HOME/Pictures"
BING_MARKET="de-DE"
BING_RESOLUTION="UHD"
NASA_API_KEY="DEMO_KEY"
NASA_APOD_FALLBACK_COUNT="10"
ESA_IMAGES_URL="https://www.esa.int/ESA_Multimedia/Images"
```

After editing the file manually, apply the timer settings:

```bash
bingwallpaper --apply
```

## Requirements

- Debian-based Linux distribution, recommended target: Zorin OS 18
- GNOME desktop with `gsettings`
- `bash`
- `curl`
- `jq`
- `systemd` user services
- `wget` only if you choose the wget install command

## Uninstall

Run:

```bash
systemctl --user disable --now bingwallpaper.timer
rm -f ~/.config/systemd/user/bingwallpaper.service ~/.config/systemd/user/bingwallpaper.timer
rm -f ~/.local/bin/bingwallpaper
systemctl --user daemon-reload
```

Optional: remove the saved settings and downloaded images:

```bash
rm -rf ~/.config/bingwallpaper
rm -f ~/Pictures/bing-wallpaper.jpg ~/Pictures/nasa-wallpaper.jpg ~/Pictures/esa-wallpaper.jpg
```
