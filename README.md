# gnome-bing-wallpaper

A basic headless script that pulls the daily wallpaper from Bing and sets it as the GNOME wallpaper.

## Script

Run:

```bash
./bing-wallpaper.sh
```

The script:

- fetches Bing's daily wallpaper metadata for the `de-DE` market,
- downloads the image to `~/Pictures/bing-wallpaper.jpg`,
- sets both `picture-uri` and `picture-uri-dark` in GNOME.

## Requirements

- `bash`
- `curl`
- `jq`
- `gsettings` (GNOME)
