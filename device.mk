#
# Copyright (C) 2024 The Android Open Source Project
# Copyright (C) 2026 AERA Recovery Project contributors
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/xiaomi/zorn

# Base product configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# Virtual A/B OTA configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression_with_xor.mk)

# Emulated storage support
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Configure twrp common.mk
$(call inherit-product, vendor/twrp/config/common.mk)

# Device-specific AERA configuration
$(call inherit-product, $(DEVICE_PATH)/aera_zorn.mk)

# Dynamic partition tools, WLAN MAC helper, and isolated plugin supervisor
PRODUCT_PACKAGES += \
    aera-browser-jail \
    aera-zorn-wlan-mac \
    lpflash \
    lpmake \
    lpunpack

ifeq ($(AERA_ENABLE_MOBILE_DATA),1)
    PRODUCT_PACKAGES += aera-cellular-provider
endif

# Shipping API level (SM8650 / pineapple BSP, GKI 6.1, 4 KiB pages)
BOARD_SHIPPING_API_LEVEL := 34
PRODUCT_SHIPPING_API_LEVEL := 34
PRODUCT_TARGET_VNDK_VERSION := 34
SHIPPING_API_LEVEL := 34

# Dynamic partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Properties
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.fuse.passthrough.enable=true \
    ro.dynamic.full_size=8321499136 \
    vendor.display.enable_spr=1

# Init (POCO F7 Pro / Redmi K80 variant detection)
$(call soong_config_set,libinit,vendor_init_lib,//$(DEVICE_PATH):libinit_zorn)

# OTA certificates
PRODUCT_EXTRA_RECOVERY_KEYS += \
    $(DEVICE_PATH)/security/releasekey \
    vendor/recovery/security/miui

# Keep touch firmware available under /lib/firmware while AERA temporarily
# mounts stock /vendor and /odm during vendor module loading.
PRODUCT_COPY_FILES += $(foreach fw,focaltech_ts_fw_zorn.bin zorn_thp_config.ini film_model.tflite glove_model.tflite smooth.tflite water_check.tflite,\
    $(DEVICE_PATH)/recovery/root/vendor/odm/firmware/$(fw):recovery/root/lib/firmware/$(fw))

# Mirror kiwi_v2 WLAN config under /vendor/firmware/wlan/qca_cld so both
# qca_cld3_kiwi_v2.ko and AERA's WLAN manager resolve it without broken symlinks.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/vendor/etc/wifi/kiwi_v2/WCNSS_qcom_cfg.ini:recovery/root/vendor/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini \
    $(DEVICE_PATH)/recovery/root/vendor/etc/wifi/kiwi_v2/WCNSS_qcom_cfg.ini:recovery/root/vendor/firmware/wlan/qca_cld/kiwi_v2/WCNSS_qcom_cfg.ini

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH)
