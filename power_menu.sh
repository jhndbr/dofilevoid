#!/usr/bin/env bash
# ==============================================================================
# power_menu.sh - Power & Session Menu for Sway / Void Linux
# ==============================================================================

# Determine launcher (fuzzel, wmenu or dmenu)
menu_cmd=""
if command -v fuzzel >/dev/null 2>&1; then
    menu_cmd="fuzzel --dmenu --prompt 󰐥\ Power\ Menu:\  -P 10 --lines 6 --width 25"
elif command -v wmenu >/dev/null 2>&1; then
    menu_cmd="wmenu -i -p 'Power Menu:'"
elif command -v bemenu >/dev/null 2>&1; then
    menu_cmd="bemenu -i -p 'Power Menu:'"
else
    menu_cmd="dmenu -i -p 'Power Menu:'"
fi

options=" Bloquear\n󰤄 Suspender\n󰜉 Reiniciar\n󰐥 Apagar\n󰍃 Cerrar Sesión"

chosen=$(echo -e "$options" | eval "$menu_cmd")

lock_screen() {
    if [ -f "$HOME/Pictures/blurred_wallpaper_void.jpg" ]; then
        swaylock --image "$HOME/Pictures/blurred_wallpaper_void.jpg" -f
    else
        swaylock -f -c 1e1e2e
    fi
}

case "$chosen" in
    *"Bloquear"*)
        lock_screen
        ;;
    *"Suspender"*)
        lock_screen &
        sleep 0.5
        if command -v loginctl >/dev/null 2>&1; then
            loginctl suspend
        elif command -v zzz >/dev/null 2>&1; then
            sudo zzz
        fi
        ;;
    *"Reiniciar"*)
        if command -v loginctl >/dev/null 2>&1; then
            loginctl reboot
        else
            sudo reboot
        fi
        ;;
    *"Apagar"*)
        if command -v loginctl >/dev/null 2>&1; then
            loginctl poweroff
        else
            sudo poweroff
        fi
        ;;
    *"Cerrar Sesión"*)
        swaymsg exit
        ;;
esac
