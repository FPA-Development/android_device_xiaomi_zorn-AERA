#!/system/bin/sh
# Ensure RFKill is available before WLAN or audio modules, and cleanly unmount
# system_dlkm afterwards so logical dm devices are never left pinned before
# Format Data / Super unmapping.

SCRIPT_NAME="$(basename "$0")"
MOUNTED_BY_US=""

LOGMSG() {
    echo "I:$@" >> /tmp/recovery.log
}

cleanup_mount() {
    if [ -n "$MOUNTED_BY_US" ]; then
        umount "$MOUNTED_BY_US" 2>/dev/null || umount -l "$MOUNTED_BY_US" 2>/dev/null || true
        if [ "$MOUNTED_BY_US" = "/mnt/aera-rfkill-system_dlkm" ]; then
            rmdir "$MOUNTED_BY_US" 2>/dev/null || true
        fi
        LOGMSG "Unmounted $MOUNTED_BY_US"
        MOUNTED_BY_US=""
    fi
}

finish() {
    cleanup_mount
    LOGMSG "---$SCRIPT_NAME end---"
    exit "$1"
}

fail() {
    LOGMSG "ERROR: $*"
    finish 1
}

rfkill_loaded() {
    grep -q '^rfkill ' /proc/modules || [ -d /sys/module/rfkill ]
}

LOGMSG "---$SCRIPT_NAME start---"

if rfkill_loaded; then
    LOGMSG "RFKill already available"
    finish 0
fi

SLOT="$(getprop ro.boot.slot_suffix)"
case "$SLOT" in
    _a|_b) ;;
    *) fail "Invalid active slot: $SLOT" ;;
esac

# Use existing /system_dlkm, otherwise mount via recovery's mechanism, otherwise our own mount
ROOT=/system_dlkm
if ! grep -q " $ROOT " /proc/mounts; then
    mount "$ROOT"
    if grep -q " $ROOT " /proc/mounts; then
        MOUNTED_BY_US="$ROOT"
        LOGMSG "Mounted $ROOT through recovery"
    else
        LOGMSG "Recovery mount of /system_dlkm unavailable; trying active-slot fallback"
        ROOT=/mnt/aera-rfkill-system_dlkm
        if ! grep -q " $ROOT " /proc/mounts; then
            PART="/dev/block/mapper/system_dlkm$SLOT"
            [ -b "$PART" ] || fail "Missing partition: $PART"
            mkdir -p "$ROOT" || fail "Could not create $ROOT"
            mount -t erofs -o ro "$PART" "$ROOT" || \
                mount -t ext4 -o ro "$PART" "$ROOT" || \
                fail "Could not mount $PART"
            MOUNTED_BY_US="$ROOT"
            LOGMSG "Mounted $PART read-only at $ROOT"
        fi
    fi
fi

for MODULE in \
    "$ROOT/flatten/lib/modules/rfkill.ko" \
    "$ROOT/lib/modules/rfkill.ko" \
    "$ROOT"/lib/modules/*/kernel/net/rfkill/rfkill.ko; do
    [ -f "$MODULE" ] || continue

    if rfkill_loaded; then
        LOGMSG "RFKill was loaded by another service"
        finish 0
    fi

    insmod "$MODULE"
    rfkill_loaded || fail "Unable to load RFKill from $MODULE"
    LOGMSG "Loaded RFKill from $MODULE"
    finish 0
done

fail "rfkill.ko not found in $ROOT"
