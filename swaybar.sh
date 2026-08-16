#!/usr/bin/env bash
# ==============================================================================
# swaybar.sh - JSON Streaming Status Bar for Sway / Void Linux
# Supports dynamic colors (Catppuccin Mocha & Light Cream) via Swaybar JSON protocol
# ==============================================================================

# Determine active theme colors (Dark default vs Light)
THEME_FILE="$HOME/.config/sway/theme"
IS_LIGHT=0
if [ -L "$THEME_FILE" ]; then
    TARGET=$(readlink -f "$THEME_FILE" 2>/dev/null || echo "")
    if [[ "$TARGET" == *"theme_light"* ]]; then
        IS_LIGHT=1
    fi
fi

if [ "$IS_LIGHT" -eq 1 ]; then
    COLOR_BG="#f2e9de"
    COLOR_FG="#575268"
    COLOR_MUTED="#9893a5"
    COLOR_RAM="#8839ef"
    COLOR_NET="#1e66f5"
    COLOR_VOL="#40a02b"
    COLOR_BRI="#df8e1d"
    COLOR_BAT="#fe640b"
    COLOR_BAT_LOW="#d20f39"
    COLOR_DATE="#7287fd"
    COLOR_SCRATCH="#ea76cb"
else
    COLOR_BG="#1e1e2e"
    COLOR_FG="#cdd6f4"
    COLOR_MUTED="#6c7086"
    COLOR_RAM="#cba6f7"
    COLOR_NET="#89b4fa"
    COLOR_VOL="#a6e3a1"
    COLOR_BRI="#f9e2af"
    COLOR_BAT="#fab387"
    COLOR_BAT_LOW="#f38ba8"
    COLOR_DATE="#b4befe"
    COLOR_SCRATCH="#f5c2e7"
fi

# Send Swaybar JSON Header
echo '{"version":1}'
echo '['
echo '[]'

get_status_json() {
    local json_blocks=()

    # --- 1. Scratchpad Windows Count ---
    if command -v jq >/dev/null 2>&1 && command -v swaymsg >/dev/null 2>&1; then
        local scratchpad
        scratchpad=$(swaymsg -t get_tree 2>/dev/null | jq -r '.nodes[] | select(.name == "__i3").nodes[] | select(.name == "__i3_scratch").floating_nodes | length' 2>/dev/null)
        if [ -n "$scratchpad" ] && [ "$scratchpad" -gt 0 ] 2>/dev/null; then
            json_blocks+=("{\"full_text\":\"󰀿 ${scratchpad}\",\"color\":\"${COLOR_SCRATCH}\",\"separator\":true,\"separator_block_width\":16}")
        fi
    fi

    # --- 2. Memory Usage (RAM) ---
    if [ -r /proc/meminfo ]; then
        local mem_total mem_avail mem_used
        mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        if [ -n "$mem_total" ] && [ -n "$mem_avail" ]; then
            mem_used=$(( (mem_total - mem_avail) / 1024 ))
            if [ "$mem_used" -gt 1024 ]; then
                local mem_gb
                mem_gb=$(awk "BEGIN {printf \"%.1f\", $mem_used / 1024}")
                json_blocks+=("{\"full_text\":\"󰍛 ${mem_gb} GB\",\"color\":\"${COLOR_RAM}\",\"separator\":true,\"separator_block_width\":16}")
            else
                json_blocks+=("{\"full_text\":\"󰍛 ${mem_used} MB\",\"color\":\"${COLOR_RAM}\",\"separator\":true,\"separator_block_width\":16}")
            fi
        fi
    fi

    # --- 3. Network Status ---
    local net_text="󱛅 Off"
    local net_color="${COLOR_MUTED}"
    if command -v nmcli >/dev/null 2>&1; then
        local active_wifi active_eth
        active_wifi=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d':' -f2 | head -n1)
        if [ -n "$active_wifi" ]; then
            net_text="󰖩 ${active_wifi}"
            net_color="${COLOR_NET}"
        else
            active_eth=$(nmcli -t -f TYPE,STATE dev 2>/dev/null | grep 'ethernet:connected')
            if [ -n "$active_eth" ]; then
                net_text="󰈀 Wired"
                net_color="${COLOR_NET}"
            fi
        fi
    elif command -v wpa_cli >/dev/null 2>&1; then
        local wifi_ssid
        wifi_ssid=$(wpa_cli status 2>/dev/null | grep '^ssid=' | cut -d'=' -f2)
        if [ -n "$wifi_ssid" ]; then
            net_text="󰖩 ${wifi_ssid}"
            net_color="${COLOR_NET}"
        elif ip route show default 2>/dev/null | grep -q 'default'; then
            net_text="󰈀 Connected"
            net_color="${COLOR_NET}"
        fi
    elif ip route show default 2>/dev/null | grep -q 'default'; then
        net_text="󰖩 Online"
        net_color="${COLOR_NET}"
    fi
    json_blocks+=("{\"full_text\":\"${net_text}\",\"color\":\"${net_color}\",\"separator\":true,\"separator_block_width\":16}")

    # --- 4. Audio Volume (wpctl / pactl) ---
    local vol_text=""
    local vol_color="${COLOR_VOL}"
    if command -v wpctl >/dev/null 2>&1; then
        local volume_info
        volume_info=$(wpctl get-volume @DEFAULT_SINK@ 2>/dev/null)
        if [ -n "$volume_info" ]; then
            if echo "$volume_info" | grep -q "\[MUTED\]"; then
                vol_text="󰖁 Muted"
                vol_color="${COLOR_BAT_LOW}"
            else
                local volume_level volume_pct
                volume_level=$(echo "$volume_info" | awk '{print $2}')
                volume_pct=$(awk "BEGIN {printf \"%.0f\", $volume_level * 100}" 2>/dev/null || echo "50")
                vol_text="󰕾 ${volume_pct}%"
            fi
        fi
    elif command -v pactl >/dev/null 2>&1; then
        local vol muted
        vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '{print $5}' | head -n1)
        muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
        if [ "$muted" = "yes" ]; then
            vol_text="󰖁 Muted"
            vol_color="${COLOR_BAT_LOW}"
        elif [ -n "$vol" ]; then
            vol_text="󰕾 ${vol}"
        fi
    fi
    if [ -n "$vol_text" ]; then
        json_blocks+=("{\"full_text\":\"${vol_text}\",\"color\":\"${vol_color}\",\"separator\":true,\"separator_block_width\":16}")
    fi

    # --- 5. Brightness (brightnessctl) ---
    if command -v brightnessctl >/dev/null 2>&1; then
        local brightness max_brightness
        brightness=$(brightnessctl get 2>/dev/null)
        max_brightness=$(brightnessctl max 2>/dev/null)
        if [ -n "$brightness" ] && [ -n "$max_brightness" ] && [ "$max_brightness" -gt 0 ] 2>/dev/null; then
            local brightness_pct=$((brightness * 100 / max_brightness))
            json_blocks+=("{\"full_text\":\"󰃠 ${brightness_pct}%\",\"color\":\"${COLOR_BRI}\",\"separator\":true,\"separator_block_width\":16}")
        fi
    fi

    # --- 6. Battery Detection & Status ---
    for bat in /sys/class/power_supply/BAT*; do
        if [ -d "$bat" ]; then
            local capacity status icon bat_color
            capacity=$(cat "$bat/capacity" 2>/dev/null)
            status=$(cat "$bat/status" 2>/dev/null)

            if [ -n "$capacity" ]; then
                icon="󰁹"
                bat_color="${COLOR_BAT}"
                if [ "$status" = "Charging" ]; then
                    icon="󰂄"
                    bat_color="${COLOR_VOL}"
                elif [ "$status" = "Discharging" ]; then
                    if [ "$capacity" -le 15 ]; then
                        icon="󰂃"
                        bat_color="${COLOR_BAT_LOW}"
                    elif [ "$capacity" -le 30 ]; then
                        icon="󰁼"
                    elif [ "$capacity" -le 60 ]; then
                        icon="󰁿"
                    elif [ "$capacity" -le 90 ]; then
                        icon="󰂁"
                    fi
                fi
                json_blocks+=("{\"full_text\":\"${icon} ${capacity}%\",\"color\":\"${bat_color}\",\"separator\":true,\"separator_block_width\":16}")
                break
            fi
        fi
    done

    # --- 7. Date & Time ---
    local date_val
    date_val=$(date +'%a %d %b  󰥔 %H:%M')
    json_blocks+=("{\"full_text\":\"󰃭 ${date_val}\",\"color\":\"${COLOR_DATE}\",\"separator\":false}")

    # Build output array
    local IFS=","
    echo ",[${json_blocks[*]}]"
}

# Continuous loop for swaybar streaming
while true; do
    get_status_json
    sleep 1
done
