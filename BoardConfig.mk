#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2025 The OrangeFox Recovery Project
# Copyright (C) 2026 AERA Recovery Project contributors
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/xiaomi/zorn

# Building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Rules
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += RTIC_MPGEN
BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults soong-libguitwrp_defaults soong-libminuitwrp_defaults soong-vold_defaults

# Architecture (Snapdragon 8 Gen 3 / SM8650)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := kryo
TARGET_CPU_VARIANT_RUNTIME := kryo300

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := $(TARGET_ARCH_VARIANT)
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := $(TARGET_CPU_VARIANT)
TARGET_2ND_CPU_VARIANT_RUNTIME := $(TARGET_CPU_VARIANT_RUNTIME)

# Power
ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# Bootloader
PRODUCT_PLATFORM := pineapple
TARGET_BOOTLOADER_BOARD_NAME := pineapple
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true

# Platform
TARGET_BOARD_PLATFORM := pineapple
TARGET_BOARD_PLATFORM_GPU := qcom-adreno750
TARGET_USES_VULKAN := true
QCOM_BOARD_PLATFORMS += xiaomi_sm8650

# Kernel (prebuilt GKI 6.1, boot header v4, 4 KiB pages)
BOARD_KERNEL_PAGESIZE := 4096
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_USES_GENERIC_KERNEL_IMAGE := true

# Ramdisk compression
BOARD_RAMDISK_USE_LZ4 := true

# A/B with dedicated recovery partition
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true

AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    odm \
    product \
    system \
    system_ext \
    system_dlkm \
    vendor \
    vendor_dlkm

# Verified Boot
BOARD_AVB_ENABLE := true

# Partitions
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600

# Dynamic Partition
BOARD_SUPER_PARTITION_SIZE := 8321499136
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 8317304832
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor vendor_dlkm system_dlkm odm

BOARD_PARTITION_LIST := $(call to-upper, $(BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval BOARD_$(p)IMAGE_FILE_SYSTEM_TYPE := erofs))
$(foreach p, $(BOARD_PARTITION_LIST), $(eval TARGET_COPY_OUT_$(p) := $(call to-lower, $(p))))

BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs

# System as root
BOARD_ROOT_EXTRA_FOLDERS := bluetooth dsp firmware persist
BOARD_SUPPRESS_SECURE_ERASE := true

# File systems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USES_VENDOR_DLKMIMAGE := true

# Workaround for error copying vendor files to recovery ramdisk
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR := vendor

# Init
TARGET_RECOVERY_DEVICE_MODULES := libinit_zorn
TARGET_PLATFORM_DEVICE_BASE := /devices/soc/

# Recovery
BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

# Crypto
FIXED_DECRYPT := true
AERA_INCLUDE_CRYPTO := $(FIXED_DECRYPT)
AERA_INCLUDE_CRYPTO_FBE := $(FIXED_DECRYPT)
AERA_INCLUDE_FBE_METADATA_DECRYPT := $(FIXED_DECRYPT)
BOARD_USES_QCOM_FBE_DECRYPTION := $(FIXED_DECRYPT)
AERA_USE_FSCRYPT_POLICY := 2

BOARD_USES_METADATA_PARTITION := true
PLATFORM_VERSION := 99.87.36
PLATFORM_SECURITY_PATCH := 2127-12-31
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# Board
TARGET_BOARD_INFO_FILE := $(DEVICE_PATH)/board-info.txt

# Tools
AERA_INCLUDE_7ZA := true
AERA_INCLUDE_ZSTD := true
AERA_INCLUDE_REPACKTOOLS := true
AERA_INCLUDE_RESETPROP := true
AERA_INCLUDE_LIBRESETPROP := true
AERA_INCLUDE_LPDUMP := true
AERA_INCLUDE_LPTOOLS := true

# Debug
TARGET_USES_LOGD := true
AERA_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd strace
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/strace

# Fastbootd
AERA_INCLUDE_FASTBOOTD := true
AERA_SKIP_ADDITIONAL_FSTAB := true

# AERA display and UI (POCO F7 Pro / Redmi K80: 1440x3200 QHD+ @ 120 Hz)
AERA_UI_ADAPTIVE_RESOLUTION := true
AERA_THEME := portrait_hdpi
AERA_FRAMERATE := 120
TARGET_SCREEN_WIDTH := 1440
TARGET_SCREEN_HEIGHT := 3200
AERA_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
AERA_MAX_BRIGHTNESS := 2047
AERA_DEFAULT_BRIGHTNESS := 250
AERA_NO_SCREEN_BLANK := true
AERA_SCREEN_BLANK_ON_BOOT := true

# Other AERA configurations
RECOVERY_SDCARD_ON_DATA := true
TARGET_RECOVERY_QCOM_RTC_FIX := true
AERA_EXCLUDE_DEFAULT_USB_INIT := true
AERA_ENABLE_FS_COMPRESSION := true
AERA_INCLUDE_NTFS_3G := true
AERA_NO_EXFAT_FUSE := false
AERA_INCLUDE_FUSE_EXFAT := true
AERA_INCLUDE_FUSE_NTFS := true
AERA_USE_TOOLBOX := true
TARGET_USES_MKE2FS := true
AERA_INPUT_BLACKLIST := "hbtp_vm"
AERA_EXTRA_LANGUAGES := true
AERA_DEFAULT_LANGUAGE := en
AERA_EXCLUDE_APEX := true
AERA_HAS_EDL_MODE := true

# Haptics
FIXED_HAPTICS := true

ifeq ($(FIXED_HAPTICS),true)
    AERA_SUPPORT_INPUT_AIDL_HAPTICS := true
    AERA_SUPPORT_INPUT_AIDL_HAPTICS_FQNAME := "IVibrator/vibratorfeature"
    AERA_SUPPORT_INPUT_AIDL_HAPTICS_FIX_OFF := true
else
    AERA_NO_HAPTICS := true
endif

# Modules, thermal, and battery
AERA_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
AERA_LOAD_VENDOR_MODULES := "adsp_loader_dlkm.ko aw882xx_dlkm.ko focaltech_touch.ko xiaomi_touch.ko nxp-nci.ko stm_st54se_gpio.ko stm_nfc_i2c.ko qti_battery_charger.ko"
AERA_POST_DECRYPT_MODULES := "smem-mailbox.ko cnss_prealloc.ko cnss_nl.ko wlan_firmware_service.ko cnss_plat_ipc_qmi_svc.ko cnss_utils.ko cnss2.ko gsim.ko rmnet_mem.ko ipam.ko rfkill.ko cfg80211.ko qca_cld3_kiwi_v2.ko"
AERA_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
AERA_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone25/temp"
AERA_BATTERY_SYSFS_WAIT_SECONDS := 6
AERA_BACKUP_EXCLUSIONS := /data/fonts,/data/adb/ap,/data/adb/ksu
