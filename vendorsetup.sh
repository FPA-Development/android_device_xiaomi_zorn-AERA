#!/bin/bash
#
# Copyright (C) 2025 The OrangeFox Recovery Project
# Copyright (C) 2026 AERA Recovery Project contributors
#
# SPDX-License-Identifier: GPL-3.0-or-later
#

FDEVICE="zorn"

aera_get_target_device() {
	export script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
	if echo "$script_path" | grep -q "$FDEVICE"; then
		AERA_BUILD_DEVICE="$FDEVICE"
	elif echo "$0" | grep -q "$FDEVICE"; then
		AERA_BUILD_DEVICE="$FDEVICE"
	fi
}

if [ -z "$AERA_BUILD_DEVICE" ]; then
	aera_get_target_device
fi

if [ "$1" = "$FDEVICE" ] || [ "$AERA_BUILD_DEVICE" = "$FDEVICE" ]; then
	echo "Detected build device: $FDEVICE"

	# AERA device build settings
	export LC_ALL="C"
	export AERA_BUILD_STATUS=Unofficial
	export AERA_BUILD_TYPE=Beta

	# A/B Partition
	export AERA_AB_DEVICE=1
	export AERA_VIRTUAL_AB_DEVICE=1
	export AERA_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
	export AERA_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"

	# Compression Binaries & Tools
	export AERA_USE_BASH_SHELL=1
	export AERA_USE_NANO_EDITOR=1
	export AERA_USE_TAR_BINARY=1
	export AERA_USE_LZ4_BINARY=1
	export AERA_USE_SED_BINARY=1
	export AERA_USE_XZ_UTILS=1
	export AERA_USE_ZSTD_BINARY=1
	export AERA_USE_DATE_BINARY=1
	export AERA_USE_FSCK_EROFS_BINARY=1
	export AERA_USE_UPDATED_MAGISKBOOT=1
	export AERA_DELETE_AROMAFM=1
	export AERA_REMOVE_AAPT=1
	export AERA_USE_BUSYBOX_BINARY=1
	export AERA_USE_GREP_BINARY=1

	# Root Manager (AERA built-in)
	export AERA_DELETE_MAGISK_ADDON=1
	export AERA_ENABLE_ROOT_MANAGER=1

	# AERA settings
	export AERA_ENABLE_MOBILE_DATA=1
	export AERA_SETTINGS_ROOT_DIRECTORY="/persist"
	# AERA begins at R1.0; do not append legacy variant or patch suffixes.
	unset AERA_VARIANT
	unset AERA_MAINTAINER_PATCH_VERSION
	export AERA_ALLOW_EARLY_SETTINGS_LOAD=1
	export AERA_RESET_SETTINGS="disabled"
else
	echo "I: vendorsetup.sh skipped; device mismatch or environment issue."
fi
