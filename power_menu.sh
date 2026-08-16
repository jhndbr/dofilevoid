#!/usr/bin/env bash
# ==============================================================================
# power_menu.sh - Power & Session Menu for Sway / Void Linux
# ==============================================================================

# Determine launcher (fuzzel, wmenu or bemenu)
menu_cmd=""
if command -v fuzzel >/dev/null 2>&1; then
    menu_cmd="fuzzel --dmenu --prompt '󰐥  Sesión: ' --lines 5 --width 24 --horizontal-pad 20 --vertical-pad 14 --radius 12"
elif command -v wmenu >/dev/null 2>&1; then
    menu_cmd="wmenu -i -p 'Sesión:'"
elif command -v bemenu >/dev/null 2>&1; then
    menu_cmd="bemenu -i -p 'Sesión:'"
else
    menu_cmd="dmenu -i -p 'Sesión:'"
fi

options="  Bloquear pantalla\n󰤄  Suspender equipo\n󰜉  Reiniciar sistema\n󰐥  Apagar sistema\n󰍃  Cerrar sesión"

chosen=$(echo -e "$options" | eval "$menu_cmd")

lock_screen() {
    # Swaylock with Catppuccin themed indicator rings
    local lock_args=(
        -f
        --indicator
        --indicator-radius 75
        --indicator-thickness 6
        --inside-color 1e1e2ecc
        --inside-clear-color f5c2e7cc
        --inside-ver-color 89b4facc
        --inside-wrong-color f38ba8cc
        --ring-color 89b4fa
        --ring-clear-color f5c2e7
        --ring-ver-color 89b4fa
        --ring-wrong-color f38ba8
        --key-hl-color a6e3a1
        --bs-hl-color f38ba8
        --line-color 00000000
        --separator-color 00000000
        --text-color cdd6f4
        --text-clear-color 1e1e2e
        --text-ver-color 1e1e2e
        --text-wrong-color 1e1e2e
    )

    if [ -f "$HOME/Pictures/blurred_wallpaper_void.jpg" ]; then
        swaylock -i "$HOME/Pictures/blurred_wallpaper_void.jpg" "${lock_args[@]}" 2>/dev/null || swaylock -f -i "$HOME/Pictures/blurred_wallpaper_void.jpg"
    elif [ -f "$HOME/Pictures/dark_theme.png" ]; then
        swaylock -i "$HOME/Pictures/dark_theme.png" "${lock_args[@]}" 2>/dev/null || swaylock -f -c 1e1e2e
    else
        swaylock -c 1e1e2e "${lock_args[@]}" 2>/dev/null || swaylock -f -c 1e1e2e
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
    *"Cerrar"*)
        swaymsg exit
        ;;
esac
