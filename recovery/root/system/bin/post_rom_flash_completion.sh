#!/system/bin/sh

SCRIPT_NAME="$(basename "$0")"

LOGMSG() {
    echo "I:$@" >> /tmp/recovery.log
}

LOGMSG "---$SCRIPT_NAME start---"

if [ -s /tmp/aera_backup.img ]; then
    for slot in _a _b; do
        if [ -e "/dev/block/bootdevice/by-name/recovery${slot}" ]; then
            LOGMSG "Restoring AERA to slot ${slot}..."
            if dd if="/tmp/aera_backup.img" of="/dev/block/bootdevice/by-name/recovery${slot}" bs=1M; then
                sync
            else
                LOGMSG "Failed to flash to slot ${slot}..."
            fi
        else
            LOGMSG "Recovery partition not found for slot ${slot}, skipping restore..."
        fi
    done
else
    LOGMSG "Unable to find the AERA recovery backup"
fi

LOGMSG "---$SCRIPT_NAME end---"
