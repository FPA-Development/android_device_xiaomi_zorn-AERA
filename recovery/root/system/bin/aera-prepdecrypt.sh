#!/system/bin/sh

SCRIPTNAME="prepdecrypt"
LOGFILE=/tmp/recovery.log

osver_twrp="99.87.36"
patchlevel_twrp="2127-12-31"

DEFAULT_LOGLEVEL=1
CUSTOM_LOGLEVEL=$(getprop $SCRIPTNAME.loglevel)
if [ -n "$CUSTOM_LOGLEVEL" ]; then
	__VERBOSE="$CUSTOM_LOGLEVEL"
else
	__VERBOSE="$DEFAULT_LOGLEVEL"
fi

log_print()
{
	case $1 in
		0|error)
			LOG_LEVEL="E"
			;;
		1|info)
			LOG_LEVEL="I"
			;;
		2|debug)
			LOG_LEVEL="DEBUG"
			;;
		*)
			LOG_LEVEL="UNKNOWN"
			;;
	esac
	if [ "$__VERBOSE" -ge "$1" ]; then
		echo "$LOG_LEVEL:$SCRIPTNAME::$2" >> "$LOGFILE"
		echo "AERA $SCRIPTNAME: $LOG_LEVEL: $2" > /dev/kmsg
	fi
}

check_setpatch_override()
{
	setpatch_prop=$(getprop $SCRIPTNAME.setpatch)
	if [ -z "$setpatch_prop" ]; then
		SETPATCH_OVERRIDE=false
	else
		SETPATCH_OVERRIDE=true
		log_print 2 "SETPATCH Override flag found."
		SETPATCH=$setpatch_prop
	fi
}

restore_ramdisk_overlays()
{
	for target in /odm /vendor; do
		attempt=0
		while grep -q "^/dev/block/.* $target " /proc/mounts; do
			attempt=$((attempt + 1))
			if [ "$attempt" -gt 4 ] || ! umount -l "$target"; then
				log_print 0 "Cannot restore recovery $target overlay."
				return 1
			fi
		done
	done

	# Preserve recovery's packaged eSE trustlets in /vendor/firmware_mnt/image
	# while exposing remaining slot-matched modem firmware files via symlinks.
	if [ -d /firmware/image ]; then
		mkdir -p /vendor/firmware_mnt/image
		for firmware in /firmware/image/*; do
			[ -e "$firmware" ] || continue
			target="/vendor/firmware_mnt/image/${firmware##*/}"
			[ -e "$target" ] || ln -s "$firmware" "$target"
		done
	fi
	log_print 1 "Recovery vendor/odm restored; packaged trustlets preserved."
	return 0
}

cleanup_temp_mounts()
{
	if [ "$SETPATCH" = "true" ]; then
		is_system_mounted=$(getprop $SCRIPTNAME.system_mounted)
		if [ "$is_system_mounted" = 1 ]; then
			umount "$TEMPSYS" 2>/dev/null
			$setprop_bin $SCRIPTNAME.system_mounted 0
			rmdir "$TEMPSYS" 2>/dev/null
		fi
		if [ "$MNT_VENDOR" = "true" ]; then
			is_vendor_mounted=$(getprop $SCRIPTNAME.vendor_mounted)
			if [ "$is_vendor_mounted" = 1 ]; then
				umount "$TEMPVEN" 2>/dev/null
				$setprop_bin $SCRIPTNAME.vendor_mounted 0
				rmdir "$TEMPVEN" 2>/dev/null
			fi
		fi
	fi
}

wait_for_crypto_hals()
{
	setprop aera.prepdecrypt.done 1
	waited=0
	while [ "$waited" -lt 40 ]; do
		if [ "$(getprop vendor.sys.listeners.registered)" = "true" ]; then
			# Give KeyMint/StrongBox/Gatekeeper/eSE/Weaver a moment to register
			sleep 1
			log_print 1 "QSEE listeners ready after $((waited * 200))ms."
			return 0
		fi
		sleep 0.2
		waited=$((waited + 1))
	done
	log_print 0 "Timed out waiting for vendor.sys.listeners.registered; continuing."
	return 1
}

finish()
{
	cleanup_temp_mounts
	restore_ramdisk_overlays
	wait_for_crypto_hals
	setprop crypto.ready 1
	log_print 1 "crypto.ready=$(getprop crypto.ready)"
	log_print 1 "Script complete. Device ready for decryption."
	exit 0
}

finish_error()
{
	cleanup_temp_mounts
	restore_ramdisk_overlays
	wait_for_crypto_hals
	setprop crypto.ready 1
	log_print 0 "Script run incomplete. Proceeding with default recovery props."
	exit 2
}

check_dynamic()
{
	dynamic_partitions=$(getprop ro.boot.dynamic_partitions)
	if [ "$dynamic_partitions" = "true" ]; then
		if [ ! -e "/dev/block/mapper/system$suffix" ] && [ ! -e "/dev/block/mapper/vendor$suffix" ]; then
			log_print 1 "/dev/block/mapper/system$suffix and /dev/block/mapper/vendor$suffix not found; unsetting suffix"
			unset suffix
		fi
	fi
}

check_resetprop()
{
	if [ -x /system/bin/resetprop ] || [ -x /sbin/resetprop ]; then
		log_print 2 "Resetprop binary found!"
		setprop_bin=resetprop
	else
		log_print 2 "Resetprop binary not found. Falling back to setprop."
		setprop_bin=setprop
	fi
}

temp_mount()
{
	is_mounted=$(ls -A "$1" 2>/dev/null)
	if [ -n "$is_mounted" ]; then
		log_print 1 "$2 already mounted."
	else
		mkdir -p "$1"
		if [ ! -d "$1" ]; then
			log_print 0 "Unable to create temporary $2 folder."
			finish_error
		fi
		mount -o ro "$3" "$1"
		is_mounted=$(ls -A "$1" 2>/dev/null)
		if [ -n "$is_mounted" ]; then
			log_print 2 "$2 mounted at $1."
			$setprop_bin "$SCRIPTNAME.${2}_mounted" 1
		else
			log_print 0 "Unable to mount $2 ($3) to $1."
			finish_error
		fi
	fi
}

set_prop_and_default()
{
	prop_name="$1"
	prop_val="$2"
	[ -z "$prop_val" ] && return 0
	$setprop_bin "$prop_name" "$prop_val"
	if [ -w "/$DEFAULTPROP" ]; then
		if grep -q "^${prop_name}=" "/$DEFAULTPROP" 2>/dev/null; then
			sed -i "s|^${prop_name}=.*|${prop_name}=${prop_val}|g" "/$DEFAULTPROP"
		else
			echo "${prop_name}=${prop_val}" >> "/$DEFAULTPROP"
		fi
	fi
	log_print 1 "Set ${prop_name}=${prop_val}"
}

log_print 1 "Running $SCRIPTNAME script for AERA..."

check_resetprop
DEFAULTPROP=prop.default
MNT_VENDOR=false
TEMPSYS=/s
TEMPVEN=/v

encrypt_type=$(getprop ro.crypto.type)
if [ "$encrypt_type" = "file" ]; then
	log_print 1 "File Based Encryption (FBE) is present."
elif [ "$encrypt_type" = "block" ]; then
	log_print 1 "Full Device Encryption (FDE) found."
else
	log_print 1 "Encryption type not set ($encrypt_type); restoring overlays and finishing."
	finish
fi

ab_device=$(getprop ro.build.ab_update)
suffix=""
if [ -n "$ab_device" ]; then
	suffix=$(getprop ro.boot.slot_suffix)
	if [ -z "$suffix" ]; then
		suf=$(getprop ro.boot.slot)
		[ -n "$suf" ] && suffix="_$suf"
	fi
	log_print 1 "Current boot slot: $suffix"
fi

SETPATCH=true
check_setpatch_override
log_print 1 "SETPATCH=$SETPATCH"

if [ "$SETPATCH" = "false" ]; then
	finish
fi

check_dynamic

MNT_VENDOR=true
venpath="/dev/block/mapper/vendor$suffix"
if [ ! -e "$venpath" ]; then
	venpath="/dev/block/bootdevice/by-name/vendor$suffix"
fi

temp_mount "$TEMPVEN" "vendor" "$venpath"

if [ -f "$TEMPVEN/build.prop" ]; then
	venpatchlevel_device=$(grep -i -m 1 'ro.vendor.build.security_patch=' "$TEMPVEN/build.prop" | cut -f2 -d'=' -s)
	set_prop_and_default "ro.vendor.build.security_patch" "$venpatchlevel_device"
fi

syspath="/dev/block/mapper/system$suffix"
if [ ! -e "$syspath" ]; then
	syspath="/dev/block/bootdevice/by-name/system$suffix"
fi

temp_mount "$TEMPSYS" "system" "$syspath"

BUILDPROP="system/build.prop"
if [ ! -f "$TEMPSYS/$BUILDPROP" ] && [ -f "$TEMPSYS/build.prop" ]; then
	BUILDPROP="build.prop"
fi

if [ -f "$TEMPSYS/$BUILDPROP" ]; then
	osver=$(grep -i -m 1 'ro.build.version.release=' "$TEMPSYS/$BUILDPROP" | cut -f2 -d'=' -s)
	patchlevel=$(grep -i -m 1 'ro.build.version.security_patch=' "$TEMPSYS/$BUILDPROP" | cut -f2 -d'=' -s)
	set_prop_and_default "ro.build.version.release" "$osver"
	set_prop_and_default "ro.build.version.security_patch" "$patchlevel"
	finish
else
	log_print 0 "System build.prop not found under $TEMPSYS."
	finish_error
fi
