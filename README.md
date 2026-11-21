# AERA Recovery Device Tree for POCO F7 Pro (`zorn`)

Device tree for building **AERA Recovery (Android 16 / `aera-16.0`)** for the **Xiaomi POCO F7 Pro / Redmi K80** (`zorn`), powered by Qualcomm Snapdragon 8 Gen 3 (`SM8650` / `pineapple`).

## Device Specifications

| Spec | Details |
| :--- | :--- |
| Device | POCO F7 Pro / Redmi K80 (`zorn`) |
| SoC | Qualcomm SM8650-AB Snapdragon 8 Gen 3 (4 nm) |
| Board / Platform | `pineapple` / `xiaomi_sm8650` |
| CPU | Octa-core Kryo (1x Cortex-X4 + 5x Cortex-A720 + 2x Cortex-A520) |
| GPU | Adreno 750 (`qcom-adreno750`) |
| Display | 6.67" AMOLED, 1440 x 3200 px (QHD+, 20:9), 120 Hz |
| Kernel | Prebuilt GKI 6.1 (`6.1.118-android14-11`, 4 KiB pages, boot header v4) |
| Storage | UFS 4.0 (Virtual A/B, dedicated `recovery_a`/`recovery_b`) |
| Super Partition | `8321499136` bytes (`qti_dynamic_partitions`) |
| Recovery Partition | `104857600` bytes (100 MiB) |
| Battery | 6000 mAh |

## Features

- Native AERA Recovery 16.0 LVGL UI with 1:1 adaptive resolution (`1440x3200` @ 120 Hz)
- FBEv2 + wrappedkey + NXP StrongBox KeyMint / Weaver / eSE / OMAPI decryption
- FocalTech touchscreen (`focaltech_touch.ko` + `touch_report`)
- Xiaomi AIDL Haptics (`IVibrator/vibratorfeature`)
- Wi-Fi (`qca_cld3_kiwi_v2.ko` / `cnss-kiwi` + per-device MAC provisioning)
- Mobile Data (`aera-cellular-provider` integrated Qualcomm MSS over QRTR/QMI)
- Dynamic USB-OTG watcher (`aera-otg-watch`) supporting multi-partition drives
- Built-in AERA Root Manager (`AERA_ROOT_MODULE_KERNELS := 6.1`)
- Adreno 750 KGSL bring-up (`aera_gpu_ready.sh`) and `aera-browser-jail`
- Dual-LED Flashlight helper (`zorn_flashlight.sh`)
- Automatic AERA recovery preservation across ROM flashes (`pre_rom_flash.sh` / `post_rom_flash_completion.sh`)

## Build Instructions

1. Sync the AERA Recovery 16.0 manifest:

```bash
mkdir -p ~/android/AERA_16.0
cd ~/android/AERA_16.0
repo init -u https://github.com/AERA-Recovery/android_manifest.git -b aera-16.0
repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc)
```

2. Clone this device tree into `device/xiaomi/zorn`:

```bash
git clone -b aera-16.0 \
  https://github.com/FPA-Development/android_device_xiaomi_zorn-AERA.git \
  device/xiaomi/zorn
```

3. Build AERA Recovery:

```bash
source build/envsetup.sh
lunch twrp_zorn-bp2a-eng
mka adbd recoveryimage
```

Output image will be generated at `out/target/product/zorn/recovery.img` (and the AERA installer zip in `out/target/product/zorn/`).

## Notes

- **Graphics**: Uses AERA's default software renderer fallback until `zorn`-matched stock Adreno 750 EGL/GLES and Qualcomm allocator blobs are bundled; `aera_gpu_ready.sh` stages `gen70900`/`gen71100` firmware from the active ROM and loads `msm_kgsl.ko` for `/dev/kgsl-3d0` (sandboxed plugins / AERA Browser).
- **Root Manager**: Enabled via `AERA_ENABLE_ROOT_MANAGER=1` with `AERA_ROOT_MODULE_KERNELS := 6.1`.
- **Variant Detection**: `libinit_zorn` detects `ro.boot.hwc=CN` (Redmi K80) vs Global (POCO F7 Pro).
