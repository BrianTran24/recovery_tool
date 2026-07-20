#include "device_handlers.h"
#include "platform_config.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// === GOPRO Logic ===

typedef enum {
    GOPRO_MAIN,
    GOPRO_LRV,
    GOPRO_METADATA,
    GOPRO_UNKNOWN
} GoProClusterType;

// Re-implementing helper functions locally or making them public in carver.h
extern int parse_hevc_sps_dims(const uint8_t* sps, size_t len, int* w, int* h);

static GoProClusterType classify_gopro_cluster(const uint8_t* buf, size_t len) {
    if (len >= 12) {
        if (memcmp(buf, "DEVC", 4) == 0 || memcmp(buf + 8, "DEVC", 4) == 0) return GOPRO_METADATA;
    }
    for (size_t i = 0; i < len - 32; i++) {
        if (buf[i] == 0x00 && buf[i+1] == 0x00 && (buf[i+2] == 0x01 || (buf[i+2] == 0x00 && buf[i+3] == 0x01))) {
            size_t start_code_len = (buf[i+2] == 0x01) ? 3 : 4;
            const uint8_t* nalu = buf + i + start_code_len;
            if (nalu[0] == 0x42 && nalu[1] == 0x01) {
                int w = 0, h = 0;
                if (parse_hevc_sps_dims(nalu, len - (i + start_code_len), &w, &h)) {
                    if (w >= 1920) return GOPRO_MAIN;
                    if (w > 0 && w <= 1280) return GOPRO_LRV;
                }
            }
        }
    }
    if (len >= 16 && memcmp(buf + 4, "ftyp", 4) == 0) {
        if (memcmp(buf + 8, "gopro", 5) == 0) return GOPRO_MAIN;
    }
    return GOPRO_UNKNOWN;
}

static int extract_gopro(int fd, uint64_t start_byte, uint64_t max_size, const char* output_path, uint64_t* out_written) {
    FILE* out = fopen(output_path, "wb");
    if (!out) return -1;

    const size_t cluster_size = 64 * 1024;
    uint8_t* buf = (uint8_t*)malloc(cluster_size);
    if (!buf) { fclose(out); return -1; }

    uint64_t pos = start_byte;
    uint64_t end = start_byte + max_size;
    uint64_t total_written = 0;
    int consecutive_lrv = 0;

    if (LSEEK(fd, (off_t_64)pos, SEEK_SET) >= 0 && READ(fd, buf, (uint32_t)cluster_size) == (ssize_t)cluster_size) {
        fwrite(buf, 1, cluster_size, out);
        total_written += cluster_size;
        pos += cluster_size;
    }

    while (pos < end) {
        if (LSEEK(fd, (off_t_64)pos, SEEK_SET) < 0) break;
        ssize_t n = READ(fd, buf, (uint32_t)cluster_size);
        if (n <= 0) break;

        GoProClusterType type = classify_gopro_cluster(buf, (size_t)n);
        if (type == GOPRO_MAIN || type == GOPRO_METADATA) {
            fwrite(buf, 1, (size_t)n, out);
            total_written += (size_t)n;
            consecutive_lrv = 0;
        } else if (type == GOPRO_LRV) {
            consecutive_lrv++;
        } else {
            if (consecutive_lrv == 0) {
                fwrite(buf, 1, (size_t)n, out);
                total_written += (size_t)n;
            }
        }
        pos += (uint64_t)n;
        if (consecutive_lrv > 200) break;
    }

    fclose(out);
    free(buf);
    if (out_written) *out_written = total_written;
    return 0;
}

// === DJI Logic ===

int is_dji_device(const uint8_t* buf, size_t len) {
    if (len < 1024) return 0;
    // Look for DJI-specific metadata tags
    for (size_t i = 0; i < len - 4; i++) {
        if (memcmp(buf + i, "DJI ", 4) == 0) return 1;
    }
    return 0;
}

static int extract_dji(int fd, uint64_t start_byte, uint64_t max_size, const char* output_path, uint64_t* out_written) {
    // DJI often interleaves data with "DJI " header blocks for metadata.
    // This is a simplified de-interleaver.
    FILE* out = fopen(output_path, "wb");
    if (!out) return -1;

    const size_t block_size = 32 * 1024;
    uint8_t* buf = (uint8_t*)malloc(block_size);
    if (!buf) { fclose(out); return -1; }

    uint64_t pos = start_byte;
    uint64_t end = start_byte + max_size;
    uint64_t total_written = 0;

    while (pos < end) {
        if (LSEEK(fd, (off_t_64)pos, SEEK_SET) < 0) break;
        ssize_t n = READ(fd, buf, (uint32_t)block_size);
        if (n <= 0) break;

        // Skip blocks that start with DJI metadata markers if they are not part of mdat
        int skip = 0;
        if (n >= 12 && memcmp(buf, "DJI ", 4) == 0) {
             // In some DJI formats, metadata is interleaved.
             // We keep it for now as it's often part of the MP4 structure,
             // but could be skipped if it's proven to be a separate stream.
        }

        if (!skip) {
            fwrite(buf, 1, (size_t)n, out);
            total_written += (size_t)n;
        }
        pos += (uint64_t)n;
    }

    fclose(out);
    free(buf);
    if (out_written) *out_written = total_written;
    return 0;
}

// === Dispatcher ===

int is_gopro_device(const uint8_t* buf, size_t len) {
    if (len < 16) return 0;
    if (memcmp(buf + 4, "ftyp", 4) == 0) {
        if (memcmp(buf + 8, "gopro", 5) == 0 || memcmp(buf + 8, "GoPro", 5) == 0) return 1;
    }
    for (size_t i = 0; i < len - 5; i++) {
        if (memcmp(buf + i, "GoPro", 5) == 0) return 1;
        if (i < len - 4 && memcmp(buf + i, "DEVC", 4) == 0) return 1;
    }
    return 0;
}

int handle_device_carve(int fd, uint64_t start_byte, uint64_t max_size, const char* output_path, int device_id, uint64_t* out_written) {
    if (device_id == DEVICE_GOPRO) {
        return extract_gopro(fd, start_byte, max_size, output_path, out_written);
    } else if (device_id == DEVICE_DJI) {
        return extract_dji(fd, start_byte, max_size, output_path, out_written);
    }
    return -1;
}
