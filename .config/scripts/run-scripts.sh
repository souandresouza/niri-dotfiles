#!/bin/bash
# run-scripts.sh -- executa scripts de cores (manualmente, Mod+G)

COLOR_DIR="$HOME/.config/scripts/colors"

"$COLOR_DIR/cava-colors.sh"
"$COLOR_DIR/fuzzel-colors.sh"
"$COLOR_DIR/kitty-colors.sh"
"$COLOR_DIR/niri-colors.sh"
"$COLOR_DIR/swaync-colors.sh"
"$COLOR_DIR/waybar-colors.sh"
"$COLOR_DIR/zathura-colors.sh"

if command -v wal-telegram &>/dev/null || pacman -Q wal-telegram-git &>/dev/null; then
    "$COLOR_DIR/telegram-colors.sh"
fi
