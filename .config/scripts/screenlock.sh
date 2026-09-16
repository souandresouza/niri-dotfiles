#!/bin/bash
# screenlock.sh -- trava a tela com o wallpaper atual
set -eu

WALLPAPER="$HOME/.cache/current_wallpaper.png"

if [ ! -f "$WALLPAPER" ]; then
    exec swaylock -f -c 121212
fi

exec swaylock -f -s fill -i "$WALLPAPER"