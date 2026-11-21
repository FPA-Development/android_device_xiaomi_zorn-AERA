#!/system/bin/sh
# Dual-LED flashlight bridge for POCO F7 Pro / Redmi K80 (zorn / SM8650).
# Exposes a standard brightness control node at /tmp/flashlight for AERA UI.

DIR="/tmp/flashlight"
STATE_FILE="$DIR/brightness"
MAX_FILE="$DIR/max_brightness"

SWITCH=""
for cand in \
    /sys/class/leds/led:switch_2/brightness \
    /sys/class/leds/led:switch_0/brightness \
    /sys/class/leds/led:switch/brightness; do
    if [ -w "$cand" ]; then
        SWITCH="$cand"
        break
    fi
done

TORCH_0="/sys/class/leds/led:torch_0/brightness"
TORCH_1="/sys/class/leds/led:torch_1/brightness"

rm -rf "$DIR"
mkdir -p "$DIR"

echo 1 > "$MAX_FILE"
echo 0 > "$STATE_FILE"
chmod 666 "$MAX_FILE" "$STATE_FILE"

[ -n "$SWITCH" ] && echo 0 > "$SWITCH" 2>/dev/null
[ -w "$TORCH_0" ] && echo 0 > "$TORCH_0" 2>/dev/null
[ -w "$TORCH_1" ] && echo 0 > "$TORCH_1" 2>/dev/null

LAST=""

while true; do
    STATE=""
    IFS= read -r STATE < "$STATE_FILE"

    case "$STATE" in
        1|[1-9]*)
            if [ "$LAST" != "1" ]; then
                [ -w "$TORCH_0" ] && echo 40 > "$TORCH_0" 2>/dev/null
                [ -w "$TORCH_1" ] && echo 40 > "$TORCH_1" 2>/dev/null
                [ -n "$SWITCH" ] && echo 1 > "$SWITCH" 2>/dev/null
                LAST="1"
            fi
            ;;
        *)
            if [ "$LAST" != "0" ]; then
                [ -n "$SWITCH" ] && echo 0 > "$SWITCH" 2>/dev/null
                [ -w "$TORCH_0" ] && echo 0 > "$TORCH_0" 2>/dev/null
                [ -w "$TORCH_1" ] && echo 0 > "$TORCH_1" 2>/dev/null
                LAST="0"
            fi
            ;;
    esac

    sleep 0.1
done
