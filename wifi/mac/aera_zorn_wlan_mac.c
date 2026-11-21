/*
 * Copyright (C) 2026 AERA Recovery Project contributors
 * SPDX-License-Identifier: Apache-2.0
 *
 * WLAN MAC provisioning for POCO F7 Pro / Redmi K80 (zorn / kiwi_v2).
 * Copies factory /persist/wlan/wlan_mac.bin when available, otherwise writes
 * a deterministic per-device locally-administered MAC derived from serialno
 * into recovery ramdisk firmware paths. Never modifies a mounted live ROM
 * /vendor partition.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/system_properties.h>
#include <unistd.h>

#define PERSIST_MAC_PATH "/persist/wlan/wlan_mac.bin"
#define MAC_FW_DIR       "/vendor/firmware/wlan/qca_cld/kiwi_v2"
#define MAC_FW_PATH      "/vendor/firmware/wlan/qca_cld/kiwi_v2/wlan_mac.bin"
#define MAC_ETC_DIR      "/vendor/etc/wifi/kiwi_v2"
#define MAC_ETC_PATH     "/vendor/etc/wifi/kiwi_v2/wlan_mac.bin"

static uint64_t fnv1a64(const char *serial) {
    uint64_t hash = UINT64_C(1469598103934665603);
    const char *sections[] = { "AERA-WLAN-v1:", serial };
    for (size_t part = 0; part < 2; ++part) {
        const unsigned char *p = (const unsigned char *) sections[part];
        while (*p) {
            hash ^= *p++;
            hash *= UINT64_C(1099511628211);
        }
    }
    return hash;
}

static int ensure_dir(const char *path) {
    char tmp[256];
    const size_t len = strlen(path);
    if (len == 0 || len >= sizeof(tmp)) return -1;
    memcpy(tmp, path, len + 1);
    for (char *p = tmp + 1; *p; ++p) {
        if (*p == '/') {
            *p = '\0';
            if (mkdir(tmp, 0755) != 0 && errno != EEXIST) return -1;
            *p = '/';
        }
    }
    if (mkdir(tmp, 0755) != 0 && errno != EEXIST) return -1;
    return 0;
}

static int write_file_exact(const char *path, const char *buf, size_t len) {
    const int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC | O_NOFOLLOW, 0644);
    if (fd < 0) {
        perror(path);
        return -1;
    }
    size_t written = 0;
    while (written < len) {
        const ssize_t count = write(fd, buf + written, len - written);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) {
            perror(path);
            close(fd);
            return -1;
        }
        written += (size_t)count;
    }
    if (fchmod(fd, 0644) != 0) {
        perror(path);
        close(fd);
        return -1;
    }
    if (close(fd) != 0) {
        perror(path);
        return -1;
    }
    return 0;
}

static ssize_t read_factory_mac(char *buf, size_t cap) {
    const int fd = open(PERSIST_MAC_PATH, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    size_t total = 0;
    while (total < cap) {
        const ssize_t n = read(fd, buf + total, cap - total);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0) {
            close(fd);
            return -1;
        }
        if (n == 0) break;
        total += (size_t)n;
    }
    close(fd);
    return (total > 0) ? (ssize_t)total : -1;
}

int main(void) {
    /* /vendor must be the recovery ramdisk, not a mounted live-ROM partition. */
    FILE *mounts = fopen("/proc/mounts", "r");
    if (!mounts) {
        perror("early MAC: open /proc/mounts");
        return 1;
    }
    char line[1024];
    while (fgets(line, sizeof(line), mounts)) {
        char device[256], mountpoint[256];
        if (sscanf(line, "%255s %255s", device, mountpoint) == 2 &&
            strcmp(mountpoint, "/vendor") == 0) {
            fclose(mounts);
            fputs("early MAC: /vendor is mounted; refusing to write to ROM\n", stderr);
            return 1;
        }
    }
    fclose(mounts);

    if (ensure_dir(MAC_FW_DIR) != 0 || ensure_dir(MAC_ETC_DIR) != 0) {
        fputs("early MAC: failed to prepare recovery firmware directories\n", stderr);
        return 1;
    }

    char contents[512];
    ssize_t length = read_factory_mac(contents, sizeof(contents));
    const int from_persist = (length > 0);

    if (!from_persist) {
        char serial[PROP_VALUE_MAX] = {0};
        if (__system_property_get("ro.serialno", serial) <= 0 || !serial[0]) {
            memset(serial, 0, sizeof(serial));
            __system_property_get("ro.boot.serialno", serial);
        }
        if (!serial[0]) {
            fputs("early MAC: no serial property; refusing shared fallback MAC\n", stderr);
            return 1;
        }
        const uint64_t hash = fnv1a64(serial);
        const unsigned char mac[6] = {
            0x02,
            (unsigned char)(hash),
            (unsigned char)(hash >> 8),
            (unsigned char)(hash >> 16),
            (unsigned char)(hash >> 24),
            (unsigned char)(hash >> 32),
        };
        const int n = snprintf(contents, sizeof(contents),
            "Intf0MacAddress=%02X%02X%02X%02X%02X%02X\n",
            mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
        if (n <= 0 || (size_t)n >= sizeof(contents)) return 1;
        length = (ssize_t)n;
    }

    if (write_file_exact(MAC_FW_PATH, contents, (size_t)length) != 0) return 1;
    (void)write_file_exact(MAC_ETC_PATH, contents, (size_t)length);

    if (from_persist) {
        puts("early MAC: staged factory wlan_mac.bin from /persist");
    } else {
        puts("early MAC: generated AERA-compatible per-device wlan_mac.bin");
    }
    return 0;
}
