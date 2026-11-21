#!/system/bin/sh
# Stage device-matched Adreno 750 (gen70900 / gen71100) firmware from the
# installed ROM's active vendor/odm partitions into recovery RAM and load
# msm_kgsl.ko for /dev/kgsl-3d0 (required by AERA Browser / sandboxed GPU plugins).

PATH=/system/bin:/sbin:/vendor/bin
export PATH
LOG=/tmp/aera_gpu_ready.log

log() {
    echo "[aera-gpu] uptime=$(cut -d ' ' -f 1 /proc/uptime) $*" >> "$LOG"
    echo "[aera-gpu] $*" > /dev/kmsg 2>/dev/null || true
}

prop() { getprop "$1" 2>/dev/null; }

mount_ro() {
    part="$1"
    mp="$2"
    mount -t erofs -o ro "$part" "$mp" 2>> "$LOG" || \
        mount -t ext4 -o ro "$part" "$mp" 2>> "$LOG" || \
        mount -o ro "$part" "$mp" 2>> "$LOG"
}

mod_loaded() {
    mod="$1"
    mod_us="$(echo "$mod" | tr '-' '_')"
    grep -Eq "^(${mod}|${mod_us}) " /proc/modules 2>/dev/null || [ -d "/sys/module/${mod_us}" ]
}

try_insmod_dir() {
    mod="$1"
    base_dir="$2"
    mod_loaded "$mod" && return 0
    for ko in "$base_dir/$mod.ko" "$base_dir"/*/"$mod.ko"; do
        [ -f "$ko" ] || continue
        if insmod "$ko" 2>> "$LOG"; then
            log "Loaded $mod from $ko"
            return 0
        else
            log "insmod failed for $ko"
        fi
    done
    return 1
}

if [ "$(prop ro.aera.fastbootd)" = "1" ] || [ "$(prop ro.aera.fastbootd)" = "true" ] || \
   [ "$(prop ro.twrp.fastbootd)" = "1" ] || [ "$(prop sys.usb.config.aera_fastbootd)" = "1" ]; then
    log "fastbootd active; skipping GPU bring-up"
    exit 0
fi

slot="$(prop ro.boot.slot_suffix)"

# 1. Stage gen70900* / gen71100* / a750* GPU firmware from active-slot vendor
#    and odm partitions into /lib/firmware, /vendor/firmware, and
#    /system/etc/firmware (RAM only).
mkdir -p /lib/firmware /vendor/firmware /system/etc/firmware

stage_part_fw() {
    part_name="$1"
    part_dev=""
    for cand in \
        "/dev/block/mapper/${part_name}${slot}" \
        "/dev/block/bootdevice/by-name/${part_name}${slot}" \
        "/dev/block/bootdevice/by-name/${part_name}"; do
        if [ -b "$cand" ]; then
            part_dev="$cand"
            break
        fi
    done

    if [ -z "$part_dev" ]; then
        log "No ${part_name} block device found for GPU firmware staging"
        return 0
    fi

    tmp_mp="/tmp/aera-${part_name}-gpu-fw"
    mkdir -p "$tmp_mp"
    if mount_ro "$part_dev" "$tmp_mp"; then
        copied=0
        for fw in "$tmp_mp"/firmware/gen7* "$tmp_mp"/firmware/a750*; do
            [ -f "$fw" ] || continue
            base="${fw##*/}"
            cp -f "$fw" "/lib/firmware/$base" 2>> "$LOG" || true
            cp -f "$fw" "/vendor/firmware/$base" 2>> "$LOG" || true
            cp -f "$fw" "/system/etc/firmware/$base" 2>> "$LOG" || true
            chmod 0644 "/lib/firmware/$base" "/vendor/firmware/$base" "/system/etc/firmware/$base" 2>/dev/null || true
            copied=$((copied + 1))
        done
        umount "$tmp_mp" 2>> "$LOG" || umount -l "$tmp_mp" 2>> "$LOG" || true
        rmdir "$tmp_mp" 2>/dev/null || true
        log "Staged $copied GPU firmware file(s) from $part_dev"
    else
        rmdir "$tmp_mp" 2>/dev/null || true
        log "Could not mount $part_dev read-only for GPU firmware"
    fi
}

if [ ! -e /system/etc/firmware/gen70900_sqe.fw ] || [ ! -e /system/etc/firmware/gen70900_zap.mbn ]; then
    stage_part_fw vendor
    stage_part_fw odm
fi

# Also link any gen7* zap trustlet files from /firmware/image if present
for src_dir in /firmware/image /vendor/firmware_mnt/image; do
    [ -d "$src_dir" ] || continue
    for fw in "$src_dir"/gen7* "$src_dir"/a750*; do
        [ -f "$fw" ] || continue
        base="${fw##*/}"
        [ -e "/lib/firmware/$base" ] || ln -s "$fw" "/lib/firmware/$base" 2>/dev/null || true
        [ -e "/vendor/firmware/$base" ] || ln -s "$fw" "/vendor/firmware/$base" 2>/dev/null || true
        [ -e "/system/etc/firmware/$base" ] || ln -s "$fw" "/system/etc/firmware/$base" 2>/dev/null || true
    done
done

# 2. Load msm_kgsl (and dependencies if not already loaded)
for mod in synx-driver msm_hw_fence msm_kgsl; do
    mod_loaded "$mod" && continue
    for dir in \
        /tmp/vendor_dlkm/lib/modules \
        /vendor_dlkm/lib/modules \
        /tmp/vendor/lib/modules \
        /vendor/lib/modules \
        /lib/modules; do
        [ -d "$dir" ] || continue
        try_insmod_dir "$mod" "$dir" && break
    done
done

if ! mod_loaded msm_kgsl; then
    dlkm_part=""
    for cand in \
        "/dev/block/mapper/vendor_dlkm${slot}" \
        "/dev/block/bootdevice/by-name/vendor_dlkm${slot}" \
        "/dev/block/bootdevice/by-name/vendor_dlkm"; do
        if [ -b "$cand" ]; then
            dlkm_part="$cand"
            break
        fi
    done

    tmp_dlkm="/tmp/aera-vendor-dlkm-gpu"
    if [ -n "$dlkm_part" ]; then
        mkdir -p "$tmp_dlkm"
        if mount_ro "$dlkm_part" "$tmp_dlkm"; then
            for mod in synx-driver msm_hw_fence msm_kgsl; do
                mod_loaded "$mod" && continue
                try_insmod_dir "$mod" "$tmp_dlkm/lib/modules" || \
                    try_insmod_dir "$mod" "$tmp_dlkm/flatten/lib/modules" || true
            done
            umount "$tmp_dlkm" 2>> "$LOG" || umount -l "$tmp_dlkm" 2>> "$LOG" || true
            rmdir "$tmp_dlkm" 2>/dev/null || true
        else
            rmdir "$tmp_dlkm" 2>/dev/null || true
            log "Could not mount $dlkm_part read-only for msm_kgsl.ko"
        fi
    else
        log "No vendor_dlkm block device found for msm_kgsl.ko"
    fi
fi

# 3. Wait briefly for /dev/kgsl-3d0 and ensure browser jail (uid 99090) access
n=0
while [ "$n" -lt 20 ] && [ ! -c /dev/kgsl-3d0 ]; do
    sleep 0.2
    n=$((n + 1))
done

if [ -c /dev/dma_heap/system ]; then
    chmod 0666 /dev/dma_heap/system 2>/dev/null || true
fi

if [ -c /dev/kgsl-3d0 ]; then
    chmod 0666 /dev/kgsl-3d0 2>/dev/null || true
    log "/dev/kgsl-3d0 ready"
    exit 0
fi

log "/dev/kgsl-3d0 not present after msm_kgsl load attempt"
exit 1
