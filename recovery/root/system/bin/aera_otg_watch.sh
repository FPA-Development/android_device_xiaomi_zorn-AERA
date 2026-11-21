#!/system/bin/sh
# Watch for USB OTG mass-storage disks on SM8650 (a600000.ssusb / xhci-hcd) and
# maintain /dev/block/aera_usb_otg pointing to the largest probeable data
# partition (or raw disk if unpartitioned). AERA's Check_UsbOtg_Status() polls
# /dev/block/aera_usb_otg to auto-mount and auto-unmount /usb_otg cleanly,
# including multi-partition GPT SSDs where sdg1 is an unformatted MSR/EFI part.

PATH=/system/bin:/sbin:/vendor/bin
export PATH
LINK=/dev/block/aera_usb_otg
LOG=/tmp/aera_otg_watch.log

log() {
    echo "[aera-otg] uptime=$(cut -d ' ' -f 1 /proc/uptime) $*" >> "$LOG"
}

if [ "$(getprop ro.aera.fastbootd 2>/dev/null)" = "1" ] || \
   [ "$(getprop ro.aera.fastbootd 2>/dev/null)" = "true" ] || \
   [ "$(getprop ro.twrp.fastbootd 2>/dev/null)" = "1" ] || \
   [ "$(getprop sys.usb.config.aera_fastbootd 2>/dev/null)" = "1" ]; then
    exit 0
fi

BLKID=""
for bin in /system/bin/blkid /sbin/blkid; do
    if [ -x "$bin" ]; then
        BLKID="$bin"
        break
    fi
done

is_usb_disk() {
    disk="$1"
    syslink="$(readlink "/sys/block/$disk" 2>/dev/null)"
    case "$syslink" in
        *usb*|*xhci*) return 0 ;;
        *) return 1 ;;
    esac
}

probe_fs() {
    dev="$1"
    if [ -n "$BLKID" ]; then
        "$BLKID" "$dev" 2>/dev/null | grep -iEq 'TYPE="(vfat|exfat|ntfs|ext4|ext3|ext2|f2fs)"'
    else
        busybox blkid "$dev" 2>/dev/null | grep -iEq 'TYPE="(vfat|exfat|ntfs|ext4|ext3|ext2|f2fs)"'
    fi
}

pick_best_otg_dev() {
    best_dev=""
    best_size=0
    fallback_dev=""

    for sysdisk in /sys/block/sd*; do
        [ -e "$sysdisk" ] || continue
        disk="${sysdisk##*/}"
        is_usb_disk "$disk" || continue

        # Collect partitions first, then raw disk as fallback
        found_part=0
        for part in /dev/block/"${disk}"[0-9]*; do
            [ -b "$part" ] || continue
            found_part=1
            [ -n "$fallback_dev" ] || fallback_dev="$part"
            if probe_fs "$part"; then
                pname="${part##*/}"
                sz="$(cat "/sys/class/block/$pname/size" 2>/dev/null)"
                [ -n "$sz" ] || sz=1
                if [ "$sz" -gt "$best_size" ] 2>/dev/null; then
                    best_size="$sz"
                    best_dev="$part"
                fi
            fi
        done

        if [ "$found_part" -eq 0 ] && [ -b "/dev/block/$disk" ]; then
            [ -n "$fallback_dev" ] || fallback_dev="/dev/block/$disk"
            if probe_fs "/dev/block/$disk"; then
                sz="$(cat "/sys/block/$disk/size" 2>/dev/null)"
                [ -n "$sz" ] || sz=1
                if [ "$sz" -gt "$best_size" ] 2>/dev/null; then
                    best_size="$sz"
                    best_dev="/dev/block/$disk"
                fi
            fi
        fi
    done

    if [ -n "$best_dev" ]; then
        echo "$best_dev"
    elif [ -n "$fallback_dev" ]; then
        echo "$fallback_dev"
    fi
}

has_any_usb_disk() {
    for sysdisk in /sys/block/sd*; do
        [ -e "$sysdisk" ] || continue
        disk="${sysdisk##*/}"
        if is_usb_disk "$disk"; then
            return 0
        fi
    done
    return 1
}

log "Started USB-OTG watcher (blkid=${BLKID:-busybox})"

while true; do
    if [ -L "$LINK" ]; then
        cur="$(readlink "$LINK" 2>/dev/null)"
        if [ -z "$cur" ] || [ ! -b "$cur" ]; then
            rm -f "$LINK"
            log "Removed stale OTG link ($cur)"
        fi
    else
        if has_any_usb_disk; then
            # Give ueventd a moment to create all partition nodes (sdg1..sdgN)
            sleep 1
            chosen="$(pick_best_otg_dev)"
            if [ -n "$chosen" ] && [ -b "$chosen" ]; then
                ln -sf "$chosen" "$LINK"
                fsinfo=""
                if [ -n "$BLKID" ]; then
                    fsinfo="$("$BLKID" "$chosen" 2>/dev/null)"
                fi
                log "Linked $LINK -> $chosen ($fsinfo)"
            fi
        fi
    fi
    sleep 1
done
