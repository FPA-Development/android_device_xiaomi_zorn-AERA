#!/system/bin/sh
# Stage device-matched Adreno 750 (gen70900 / gmu_gen70900 / gen71100) firmware
# from the installed ROM's active vendor and odm partitions into recovery RAM
# and ensure msm_kgsl.ko + /dev/kgsl-3d0 are ready for AERA Browser (Mesa Turnip).

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

try_insmod_file() {
    ko="$1"
    [ -f "$ko" ] || return 1
    base="${ko##*/}"
    mod="${base%.ko}"
    mod_loaded "$mod" && return 0
    if insmod "$ko" 2>> "$LOG"; then
        log "Loaded $mod from $ko"
        return 0
    else
        log "insmod failed for $ko"
        return 1
    fi
}

try_insmod_dir() {
    mod="$1"
    base_dir="$2"
    mod_loaded "$mod" && return 0
    for ko in "$base_dir/$mod.ko" "$base_dir"/*/"$mod.ko"; do
        [ -f "$ko" ] || continue
        try_insmod_file "$ko" && return 0
    done
    return 1
}

# Resolve and load msm_kgsl.ko + transitive dependencies using modules.dep
load_with_deps() {
    target_mod="$1"
    mod_dir="$2"
    dep_file="$mod_dir/modules.dep"

    if [ ! -f "$dep_file" ]; then
        for mod in synx-driver msm_hw_fence "$target_mod"; do
            try_insmod_dir "$mod" "$mod_dir" || true
        done
        return
    fi

    # Find dependency line for target_mod (e.g. "/vendor/lib/modules/msm_kgsl.ko: dep1.ko dep2.ko")
    line="$(grep -E "(^|/)${target_mod}\.ko:" "$dep_file" | head -n 1)"
    if [ -z "$line" ]; then
        try_insmod_dir "$target_mod" "$mod_dir" || true
        return
    fi

    deps="${line#*:}"
    # modules.dep lists direct + transitive deps from closest to deepest; load deepest first
    rev_deps=""
    for d in $deps; do
        rev_deps="$d $rev_deps"
    done

    for d in $rev_deps; do
        d_base="${d##*/}"
        d_name="${d_base%.ko}"
        mod_loaded "$d_name" && continue
        if [ -f "$mod_dir/$d" ]; then
            try_insmod_file "$mod_dir/$d" || true
        elif [ -f "$mod_dir/$d_base" ]; then
            try_insmod_file "$mod_dir/$d_base" || true
        else
            try_insmod_dir "$d_name" "$mod_dir" || true
        fi
    done

    try_insmod_dir "$target_mod" "$mod_dir" || true
}

stage_fw_file() {
    fw="$1"
    [ -f "$fw" ] || return 1
    base="${fw##*/}"
    for dst_dir in /lib/firmware /vendor/firmware /vendor/odm/firmware /system/etc/firmware; do
        cp -f "$fw" "$dst_dir/$base" 2>> "$LOG" || true
        chmod 0644 "$dst_dir/$base" 2>/dev/null || true
    done
    log "Staged GPU firmware: $base"
    return 0
}

if [ "$(prop ro.aera.fastbootd)" = "1" ] || [ "$(prop ro.aera.fastbootd)" = "true" ] || \
   [ "$(prop ro.twrp.fastbootd)" = "1" ] || [ "$(prop sys.usb.config.aera_fastbootd)" = "1" ]; then
    log "fastbootd active; skipping GPU bring-up"
    exit 0
fi

slot="$(prop ro.boot.slot_suffix)"

# 1. Stage Adreno 750 firmware from active-slot vendor & odm partitions into
#    RAM firmware search directories (/lib/firmware, /vendor/firmware,
#    /vendor/odm/firmware, /system/etc/firmware).
#    SM8650 (zorn) requires:
#      - vendor/firmware/gen70900_sqe.fw
#      - vendor/firmware/gen70900_aqe.fw
#      - vendor/firmware/gmu_gen70900.bin   (note gmu_ prefix!)
#      - odm/firmware/gen70900_zap.mbn
mkdir -p /lib/firmware /vendor/firmware /vendor/odm/firmware /system/etc/firmware

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
        if [ -d "$tmp_mp/firmware" ]; then
            for fw in \
                "$tmp_mp"/firmware/gen7* \
                "$tmp_mp"/firmware/gmu_gen7* \
                "$tmp_mp"/firmware/a7* \
                "$tmp_mp"/firmware/*/gen7* \
                "$tmp_mp"/firmware/*/gmu_gen7* \
                "$tmp_mp"/firmware/*/a7*; do
                [ -f "$fw" ] || continue
                stage_fw_file "$fw" && copied=$((copied + 1))
            done
        fi
        umount "$tmp_mp" 2>> "$LOG" || umount -l "$tmp_mp" 2>> "$LOG" || true
        rmdir "$tmp_mp" 2>/dev/null || true
        log "Staged $copied GPU firmware file(s) from $part_dev"
    else
        rmdir "$tmp_mp" 2>/dev/null || true
        log "Could not mount $part_dev read-only for GPU firmware"
    fi
}

if [ ! -e /system/etc/firmware/gen70900_sqe.fw ] || \
   [ ! -e /system/etc/firmware/gmu_gen70900.bin ] || \
   [ ! -e /system/etc/firmware/gen70900_zap.mbn ]; then
    stage_part_fw vendor
    stage_part_fw odm
fi

# Also link any gen7*/gmu_gen7* zap trustlet files from /firmware/image if present
for src_dir in /firmware/image /vendor/firmware_mnt/image; do
    [ -d "$src_dir" ] || continue
    for fw in "$src_dir"/gen7* "$src_dir"/gmu_gen7* "$src_dir"/a7*; do
        [ -f "$fw" ] || continue
        base="${fw##*/}"
        for dst_dir in /lib/firmware /vendor/firmware /vendor/odm/firmware /system/etc/firmware; do
            [ -e "$dst_dir/$base" ] || ln -s "$fw" "$dst_dir/$base" 2>/dev/null || true
        done
    done
done

# 2. Load msm_kgsl (and all modules.dep dependencies if not already loaded)
if ! mod_loaded msm_kgsl; then
    for dir in \
        /tmp/vendor_dlkm/lib/modules \
        /vendor_dlkm/lib/modules \
        /tmp/vendor/lib/modules \
        /vendor/lib/modules \
        /lib/modules; do
        [ -d "$dir" ] || continue
        load_with_deps msm_kgsl "$dir"
        mod_loaded msm_kgsl && break
    done
fi

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
            for sub in "$tmp_dlkm/lib/modules" "$tmp_dlkm/flatten/lib/modules" "$tmp_dlkm"/lib/modules/*; do
                [ -d "$sub" ] || continue
                load_with_deps msm_kgsl "$sub"
                mod_loaded msm_kgsl && break
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

for dev in /dev/dma_heap/system /dev/dma_heap/qcom,system /dev/kgsl-3d0; do
    if [ -c "$dev" ]; then
        chmod 0666 "$dev" 2>/dev/null || true
    fi
done

if [ -c /dev/kgsl-3d0 ]; then
    log "/dev/kgsl-3d0 ready (gmu_gen70900=$([ -e /lib/firmware/gmu_gen70900.bin ] && echo yes || echo no), zap=$([ -e /lib/firmware/gen70900_zap.mbn ] && echo yes || echo no))"
    exit 0
fi

log "/dev/kgsl-3d0 not present after msm_kgsl load attempt"
exit 1
