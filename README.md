# gnome-bing-wallpaper

A configurable GNOME wallpaper updater. It installs one command, `gnome-bing-wallpaper`, that can open a small TUI, manage the systemd user timer, and update the wallpaper from Bing, NASA APOD, or ESA Images.

## Quick install

This project includes an installer for **Zorin OS 18 (Debian-based)** that sets up the command, a config file, and a **systemd user service + timer**.

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
- installs missing dependencies (`curl`, `jq`, `systemd`, `whiptail`) when needed,
- installs the command to `~/.local/bin/gnome-bing-wallpaper`,
- creates the default config at `~/.config/gnome-bing-wallpaper/config`,
- creates and applies:
  - `~/.config/systemd/user/gnome-bing-wallpaper.service`
  - `~/.config/systemd/user/gnome-bing-wallpaper.timer`

The default timer is enabled and runs at login after 2 minutes, then every 24 hours.

## Configure the updater

After installing, use the installed command instead of running the repository script directly:

```bash
gnome-bing-wallpaper configure
```

The configuration screen lets you choose:

- whether automatic updates are enabled,
- how often the wallpaper updates,
- which source to use,
- where wallpapers are stored,
- source-specific options like Bing market, NASA API key, or ESA image listing URL.

If `whiptail` is available and you are in a terminal, the command opens a dialog-style TUI. Otherwise it falls back to a prompt-based TUI, so the same command works over SSH and in minimal environments.

## Command reference

```bash
gnome-bing-wallpaper configure          # open the TUI
gnome-bing-wallpaper status             # show config and timer state
gnome-bing-wallpaper run                # update the wallpaper now
gnome-bing-wallpaper enable             # enable the automatic timer
gnome-bing-wallpaper disable            # disable the automatic timer
gnome-bing-wallpaper set source nasa    # update one setting without the TUI
gnome-bing-wallpaper set interval 12h   # change timer frequency
gnome-bing-wallpaper help               # show all commands
```

The timer uses systemd interval values such as `30min`, `12h`, `1d`, or `1w`.

## Wallpaper sources

Supported source values:

- `bing` - Bing's daily wallpaper.
- `nasa` - NASA Astronomy Picture of the Day (APOD). If today's APOD is a video, the updater asks APOD for random image entries and uses the first image returned.
- `esa` - the latest ESA Images listing entry. ESA may block some scripted requests; if that happens, use `bing`/`nasa` or try again later.

Common non-interactive examples:

```bash
gnome-bing-wallpaper set source bing
gnome-bing-wallpaper set bing-market en-US
gnome-bing-wallpaper set bing-resolution 1920x1080
```

```bash
gnome-bing-wallpaper set source nasa
gnome-bing-wallpaper set nasa-api-key your_api_key_here
gnome-bing-wallpaper set nasa-fallback-count 20
```

```bash
gnome-bing-wallpaper set source esa
gnome-bing-wallpaper set esa-images-url https://www.esa.int/ESA_Multimedia/Images/2026/04
```

## Configuration file

The command stores settings in:

```text
~/.config/gnome-bing-wallpaper/config
```

You can edit this file directly or use `gnome-bing-wallpaper configure`. After direct edits, apply timer changes with:

```bash
gnome-bing-wallpaper install-systemd
```

The script is intentionally organized around provider functions and a central config layer so new sources and future options can be added without changing the installer or systemd unit format.

## Requirements

- GNOME desktop (`gsettings`, `gnome-shell`)
- `bash`
- `curl`
- `jq`
- `systemd` (for automated updates)
- `whiptail` (for the dialog TUI; prompt fallback is built in)
