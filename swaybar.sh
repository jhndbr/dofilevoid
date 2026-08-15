#!/usr/bin/env bash
# ==============================================================================
# swaybar.sh - Status bar generator for Sway on Void Linux
# ==============================================================================

# --- 1. Date & Time ---
date_formatted=$(date +'%a %d %b %H:%M')

# --- 2. Battery Detection & Status ---
bat_info=""
bat_display=""
for bat in /sys/class/power_supply/BAT*; do
    if [ -d "$bat" ]; then
        capacity=$(cat "$bat/capacity" 2>/dev/null)
        status=$(cat "$bat/status" 2>/dev/null)
        
        if [ -n "$capacity" ]; then
            icon="󰁹"
            if [ "$status" = "Charging" ]; then
                icon="󰂄"
                state="↑"
            elif [ "$status" = "Discharging" ]; then
                state="↓"
                if [ "$capacity" -le 15 ]; then
                    icon="󰂃"
                elif [ "$capacity" -le 30 ]; then
                    icon="󰁼"
                elif [ "$capacity" -le 60 ]; then
                    icon="󰁿"
                elif [ "$capacity" -le 90 ]; then
                    icon="󰂁"
                fi
            else
                state=""
            fi
            bat_display="[BAT ${icon} ${capacity}%${state}]"
            break
        fi
    fi
done

# --- 3. Audio Volume & Mute Status (wpctl / pactl fallback) ---
volume_display=""
if command -v wpctl >/dev/null 2>&1; then
    volume_info=$(wpctl get-volume @DEFAULT_SINK@ 2>/dev/null)
    if [ -n "$volume_info" ]; then
        if echo "$volume_info" | grep -q "\[MUTED\]"; then
            volume_display="[VOL 󰖁 Muted]"
        else
            volume_level=$(echo "$volume_info" | awk '{print $2}')
            volume_pct=$(awk "BEGIN {printf \"%.0f\", $volume_level * 100}" 2>/dev/null || echo "50")
            volume_display="[VOL 󰕾 ${volume_pct}%]"
        fi
    fi
fi

if [ -z "$volume_display" ] && command -v pactl >/dev/null 2>&1; then
    vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '{print $5}' | head -n1)
    muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
    if [ "$muted" = "yes" ]; then
        volume_display="[VOL 󰖁 Muted]"
    elif [ -n "$vol" ]; then
        volume_display="[VOL 󰕾 ${vol}]"
    fi
fi

# --- 4. Network Status ---
network_display="[NET 󱛅 Off]"
# Check NetworkManager if available
if command -v nmcli >/dev/null 2>&1; then
    active_wifi=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d':' -f2)
    if [ -n "$active_wifi" ]; then
        network_display="[NET 󰖩 $active_wifi]"
    else
        active_eth=$(nmcli -t -f TYPE,STATE dev 2>/dev/null | grep 'ethernet:connected')
        if [ -n "$active_eth" ]; then
            network_display="[NET 󰈀 Wired]"
        fi
    fi
# Fallback to wpa_cli or default route
elif command -v wpa_cli >/dev/null 2>&1; then
    wifi_ssid=$(wpa_cli status 2>/dev/null | grep '^ssid=' | cut -d'=' -f2)
    if [ -n "$wifi_ssid" ]; then
        network_display="[NET 󰖩 $wifi_ssid]"
    elif ip route show default 2>/dev/null | grep -q 'default'; then
        network_display="[NET 󰈀 Connected]"
    fi
elif ip route show default 2>/dev/null | grep -q 'default'; then
    network_display="[NET 󰖩 Online]"
fi

# --- 5. Brightness (Laptops) ---
brightness_display=""
if command -v brightnessctl >/dev/null 2>&1; then
    brightness=$(brightnessctl get 2>/dev/null)
    max_brightness=$(brightnessctl max 2>/dev/null)
    if [ -n "$brightness" ] && [ -n "$max_brightness" ] && [ "$max_brightness" -gt 0 ] 2>/dev/null; then
        brightness_pct=$((brightness * 100 / max_brightness))
        brightness_display="[BRI 󰃠 ${brightness_pct}%]"
    fi
fi

# --- 6. Memory Usage (RAM) ---
mem_display=""
if [ -r /proc/meminfo ]; then
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if [ -n "$mem_total" ] && [ -n "$mem_avail" ]; then
        mem_used=$(( (mem_total - mem_avail) / 1024 ))
        mem_display="[RAM 󰍛 ${mem_used}MB]"
    fi
fi

# --- 7. Scratchpad Windows Count ---
scratchpad_display=""
if command -v jq >/dev/null 2>&1 && command -v swaymsg >/dev/null 2>&1; then
    scratchpad=$(swaymsg -t get_tree 2>/dev/null | jq -r '.nodes[] | select(.name == "__i3").nodes[] | select(.name == "__i3_scratch").floating_nodes | length' 2>/dev/null)
    if [ -n "$scratchpad" ] && [ "$scratchpad" -gt 0 ]; then
        scratchpad_display="[# ${scratchpad}] "
    fi
fi

# --- Output to Swaybar ---
echo "${scratchpad_display}${mem_display} ${network_display} ${volume_display} ${brightness_display} ${bat_display} [󰃭 ${date_formatted}]" | tr -s ' '
