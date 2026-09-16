#!/usr/bin/env bash

set -euo pipefail

# Define config options
conf="--dmenu --match-mode=exact --launch-prefix=<not set>" # for version >= 1.11.0-1

# Define the menu options
options=("🔒\tBloquear\n""⏸\tSuspender\n""⏏\tSair\n""🔄\tReiniciar\n""⏻\tDesligar")

# Show the menu and get the user's choice
sel_option=$(echo -e "${options[@]}" | fuzzel $conf --lines=5 --prompt "Seleciona uma opção:  ")

# Check if the user selected an option
if [[ -n $sel_option ]]; then
    # Extract the action part without the glyph
    action=$(echo "$sel_option" | awk '{print $NF}')

    # Ask for confirmation
    if [[ $action == "Sair" ]]; then
       fuzzel $conf --prompt-only='Use Ctrl+Alt+Del para sair de Niri'
    else
       confirm=$(echo -e "Não - cancelar\nSim - confirmar" | fuzzel $conf --lines=2 --prompt "Confirmar $action ?  " | awk '{print $1}')

       # If the user confirmed, execute the selected option
       if [[ $confirm == "Sim" ]]; then
          case $action in
              "Bloquear")
                  "$HOME/.config/scripts/screenlock.sh"
                  ;;
              "Suspender")
                  # mpc -q pause
                  # pamixer --mute
                  systemctl suspend
                  ;;
              "Reiniciar")
                  systemctl reboot
                  ;;
              "Desligar")
                  systemctl poweroff
                  ;;
          esac
       fi
    fi
fi
# Exit the script
exit 0