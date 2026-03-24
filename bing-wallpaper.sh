#!/bin/bash

URL=$(curl -s "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=de-DE" | jq -r '.images[0].url')
FULL_URL="https://www.bing.com$URL"

mkdir -p ~/Pictures
curl -o ~/Pictures/bing-wallpaper.jpg "$FULL_URL"

gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/bing-wallpaper.jpg"
gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/Pictures/bing-wallpaper.jpg"
