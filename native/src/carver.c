#include "carver.h"
#include "platform_config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef _WIN32
#include <direct.h>
#else
#include <sys/stat.h>
#endif

#ifdef _WIN32
#define PATH_SEP '\\'
#else
#define PATH_SEP '/'
#endif

// Recursive mkdir
static void mkdir_p(const char *path) {
    char tmp[1024];
    char *p = NULL;
    size_t len;

    snprintf(tmp, sizeof(tmp), "%s", path);
    len = strlen(tmp);
    if (len == 0) return;
    if (tmp[len - 1] == PATH_SEP) tmp[len - 1] = 0;

    p = tmp;
#ifdef _WIN32
    if (len >= 3 && isalpha(tmp[0]) && tmp[1] == ':' && tmp[2] == PATH_SEP) {
        p = tmp + 3;
    }
#endif
    if (*p == PATH_SEP) p++;

    for (; *p; p++) {
        if (*p == PATH_SEP) {
            *p = 0;
            MKDIR(tmp, 0755);
            *p = PATH_SEP;
        }
    }
    MKDIR(tmp, 0755);
}

typedef enum {
    STRATEGY_FOOTER,
    STRATEGY_SIZE_FIELD,
    STRATEGY_MAX_SIZE,
    STRATEGY_SMART_VIDEO,
    STRATEGY_SMART_JPEG
} CarveStrategy;

typedef struct {
    int      fd;
    uint64_t disk_size;
    uint32_t sector_size;
    uint32_t read_chunk;
} CarverContext;

typedef struct {
    const char*   name;
    const char*   extension;
    uint8_t       header[MAX_HEADER_LEN];
    size_t        header_len;
    size_t        header_offset;
    uint8_t       footer[MAX_FOOTER_LEN];
    size_t        footer_len;
    CarveStrategy strategy;
    uint64_t      max_size;
    uint64_t      min_size;
    uint64_t (*read_size)(const CarverContext* ctx, uint64_t file_start, const uint8_t* header_buf, size_t buf_len);
    int (*validate)(const uint8_t* buf, size_t len);
} FileSignature;

#define MAX_SIGNATURE_CANDIDATES 8

typedef struct {
    const FileSignature* items[MAX_SIGNATURE_CANDIDATES];
    size_t count;
} SignatureBucket;

#define JPEG_MIN_SIZE (50ULL * 1024) // Reduced from 150KB to catch more valid photos
#define PNG_MIN_SIZE  (16ULL * 1024)

static int mp4_read_bytes(const CarverContext* ctx, uint64_t pos, const uint8_t* buf, size_t len, uint64_t file_start, uint8_t* out, size_t need) {
    if (pos >= file_start) {
        uint64_t rel = pos - file_start;
        if (rel + need <= len) {
            memcpy(out, buf + rel, need);
            return 0;
        }
    }

    if (LSEEK(ctx->fd, (off_t_64)pos, SEEK_SET) < 0) return -1;
    return (READ(ctx->fd, out, (uint32_t)need) == (ssize_t)need) ? 0 : -1;
}

static uint64_t mp4_read_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len) {
    uint64_t pos = file_start;
    uint64_t total_size = 0;
    uint8_t box_header[16];
    int found_moov = 0;
    int found_mdat = 0;

    // Duyệt qua các box của MP4 trực tiếp trên đĩa để tìm kích thước thực
    for (int i = 0; i < 200; i++) {
        if (pos + 8 > ctx->disk_size) break;

        if (mp4_read_bytes(ctx, pos, buf, len, file_start, box_header, 8) != 0) break;

        uint64_t box_size = ((uint32_t)box_header[0] << 24) | ((uint32_t)box_header[1] << 16) |
                           ((uint32_t)box_header[2] <<  8) |  (uint32_t)box_header[3];
        char type[5] = { (char)box_header[4], (char)box_header[5], (char)box_header[6], (char)box_header[7], 0 };

        if (box_size == 1) { // 64-bit size
            if (mp4_read_bytes(ctx, pos + 8, buf, len, file_start, box_header + 8, 8) != 0) break;
            box_size = 0;
            for (int j = 0; j < 8; j++) {
                box_size = (box_size << 8) | box_header[8 + j];
            }
        }

        // Kiểm tra tính hợp lệ của box type (alphanumeric)
        int valid_type = 1;
        for (int j = 0; j < 4; j++) {
            if (!((type[j] >= 'a' && type[j] <= 'z') || (type[j] >= 'A' && type[j] <= 'Z') || (type[j] >= '0' && type[j] <= '9') || type[j] == ' ')) {
                valid_type = 0;
                break;
            }
        }

        if (!valid_type || (box_size < 8 && box_size != 0)) break;

        // KIỂM TRA HỢP LỆ: Box size không được lớn hơn disk_size
        if (box_size > ctx->disk_size) break;

        if (strcmp(type, "moov") == 0) found_moov = 1;
        if (strcmp(type, "mdat") == 0) found_mdat = 1;

        if (box_size == 0) break; // Box kéo dài đến hết file

        pos += box_size;
        total_size = pos - file_start;

        if (found_moov && found_mdat && total_size > 1024 * 1024) return total_size;
        if (total_size > 10000ULL * 1024 * 1024) break; // Giới hạn an toàn 10GB
    }

    // CẢI TIẾN: Trả về kích thước ngay cả khi thiếu moov (nhưng có mdat)
    // để cứu được dữ liệu thô của các video bị lỗi/crashed
    if (found_moov || found_mdat) return total_size;
    return 0;
}

// SMART CARVER: Quét NAL units để xử lý phân mảnh
// Logic: Tìm các start code 00 00 00 01 và kiểm tra NAL type
// Nếu gặp vùng dữ liệu lạ, thử tìm start code tiếp theo trong phạm vi 1MB
static uint64_t h264_smart_carve_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len) {
    uint64_t pos = file_start;
    uint64_t last_valid_pos = file_start;
    uint8_t chunk[1024 * 64];
    const size_t chunk_size = sizeof(chunk);
    int found_sps = 0;
    int found_idr = 0;
    int continuous_errors = 0;

    // Giới hạn quét tối đa 2GB cho smart carving (tránh treo)
    uint64_t max_scan = 2000ULL * 1024 * 1024;
    if (pos + max_scan > ctx->disk_size) max_scan = ctx->disk_size - pos;

    while (pos < file_start + max_scan) {
        if (LSEEK(ctx->fd, (off_t_64)pos, SEEK_SET) < 0) break;
        ssize_t n = READ(ctx->fd, chunk, chunk_size);
        if (n < 16) break;

        int found_nal_in_chunk = 0;
        for (size_t i = 0; i < (size_t)n - 4; i++) {
            // Tìm Start Code: 00 00 00 01
            if (chunk[i] == 0x00 && chunk[i+1] == 0x00 && chunk[i+2] == 0x00 && chunk[i+3] == 0x01) {
                uint8_t nal_type = chunk[i+4] & 0x1F;
                // Các NAL type hợp lệ của H.264
                if (nal_type >= 1 && nal_type <= 12) {
                    if (nal_type == 7) found_sps = 1;
                    if (nal_type == 5) found_idr = 1;

                    last_valid_pos = pos + i + 5;
                    found_nal_in_chunk = 1;
                    continuous_errors = 0;
                }
            }
        }

        if (!found_nal_in_chunk) {
            continuous_errors++;
            // Nếu quá 2MB không thấy NAL nào, coi như kết thúc file hoặc quá phân mảnh
            if (continuous_errors > 32) break;
        }

        pos += n - 4; // Trồng lấn 4 byte để không sót start code
    }

    if (found_sps && found_idr) return last_valid_pos - file_start;
    return 0;
}

#define JPEG_MIN_SIZE (50ULL * 1024) // Reduced from 150KB to catch more valid photos
#define PNG_MIN_SIZE  (16ULL * 1024)

// JPEG Smart Carving support
#include <math.h>

double calculate_entropy(const uint8_t* data, size_t len) {
    if (len == 0) return 0.0;
    uint32_t counts[256] = {0};
    for (size_t i = 0; i < len; i++) counts[data[i]]++;

    double entropy = 0;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double p = (double)counts[i] / len;
            entropy -= p * (log(p) / log(2.0));
        }
    }
    return entropy;
}

static double jpeg_calculate_entropy(const uint8_t* data, size_t len) {
    return calculate_entropy(data, len);
}

static uint64_t jpeg_smart_carve_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len) {
    uint64_t pos = file_start;
    uint8_t marker_buf[4];

    // 1. Skip FF D8
    pos += 2;

    // 2. Parse Markers until SOS (FF DA)
    while (pos + 4 < ctx->disk_size) {
        if (LSEEK(ctx->fd, (off_t_64)pos, SEEK_SET) < 0) break;
        if (READ(ctx->fd, marker_buf, 4) != 4) break;

        if (marker_buf[0] != 0xFF) break; // Invalid marker
        uint8_t marker = marker_buf[1];
        if (marker == 0xDA) { // Start of Scan
            pos += 2; // Move to scan data
            break;
        }

        if (marker == 0xD8) { pos += 2; continue; } // Extra SOI?
        if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) { // No length markers
            pos += 2;
            continue;
        }

        uint32_t marker_len = (marker_buf[2] << 8) | marker_buf[3];
        pos += marker_len + 2;
    }

    // 3. Scan compressed data (Entropy-based)
    uint64_t last_valid_pos = pos;
    uint8_t chunk[16 * 1024];
    int continuous_low_entropy = 0;
    int found_eoi = 0;

    while (pos < file_start + (50ULL * 1024 * 1024)) { // Max 50MB for JPEG
        if (LSEEK(ctx->fd, (off_t_64)pos, SEEK_SET) < 0) break;
        ssize_t n = READ(ctx->fd, chunk, sizeof(chunk));
        if (n < 64) break;

        // Check entropy of the chunk
        double entropy = jpeg_calculate_entropy(chunk, (size_t)n);

        // JPEG compressed data usually has entropy > 7.0
        if (entropy < 6.0) {
            continuous_low_entropy++;
            if (continuous_low_entropy > 4) break; // ~64KB of low entropy = fragmentation/end
        } else {
            continuous_low_entropy = 0;
            last_valid_pos = pos + (uint64_t)n;
        }

        // Look for EOI (FF D9) in chunk
        for (size_t i = 0; i < (size_t)n - 1; i++) {
            if (chunk[i] == 0xFF && chunk[i+1] == 0xD9) {
                found_eoi = 1;
                return pos + (uint64_t)i + 2 - file_start;
            }
            // Check for restart markers if fragmented
            if (chunk[i] == 0xFF && chunk[i+1] >= 0xD0 && chunk[i+1] <= 0xD7) {
                last_valid_pos = pos + (uint64_t)i + 2;
            }
        }

        pos += (uint64_t)n;
        if (pos > ctx->disk_size) break;
    }

    if (last_valid_pos > file_start) return last_valid_pos - file_start;
    return 0;
}

static int jpeg_get_dimensions(const uint8_t* buf, size_t len, uint32_t* width, uint32_t* height) {
    if (len < 10) return 0;
    size_t pos = 2; // Skip FF D8
    while (pos + 8 < len) {
        if (buf[pos] != 0xFF) break;
        uint8_t marker = buf[pos + 1];
        uint32_t marker_len = (buf[pos + 2] << 8) | buf[pos + 3];

        // SOF0 - SOF15 (Start of Frame)
        if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
            *height = (buf[pos + 5] << 8) | buf[pos + 6];
            *width = (buf[pos + 7] << 8) | buf[pos + 8];
            return 1;
        }
        if (marker_len < 2) break;
        pos += marker_len + 2;
    }
    return 0;
}

static int jpeg_validate(const uint8_t* buf, size_t len) {
    // JPEG header: FF D8 FF
    if (len < 10) return 0;
    if (buf[0] != 0xFF || buf[1] != 0xD8 || buf[2] != 0xFF) return 0;

    // Optional: Filter out tiny thumbnails (e.g. width < 160px)
    // CẢI THIỆN: Nếu file lớn hoặc không rõ kích thước, ưu tiên giữ lại để tránh mất file gốc
    uint32_t w = 0, h = 0;
    if (jpeg_get_dimensions(buf, len, &w, &h)) {
        if (w > 0 && w < 160) return 0;
    }

    // Standard JPEG markers
    if ((buf[3] >= 0xE0 && buf[3] <= 0xEF) ||
        buf[3] == 0xDB ||
        (buf[3] >= 0xC0 && buf[3] <= 0xC3) ||
        buf[3] == 0xFE) {
        return 1;
    }

    return 0;
}


static int mp4_validate(const uint8_t* buf, size_t len) {
    if (len < 12) return 0;
    // Kiểm tra ftyp brand (phải là ký tự in được)
    for (int i = 8; i < 12; i++) {
        if (buf[i] != 0 && (buf[i] < 32 || buf[i] > 126)) return 0;
    }
    // Brand không được rỗng
    if (buf[8] == 0 && buf[9] == 0 && buf[10] == 0 && buf[11] == 0) return 0;
    return 1;
}

static FileSignature SIGNATURES[] = {
    {
        .name = "JPEG", .extension = ".jpg",
        .header = {0xFF, 0xD8, 0xFF}, .header_len = 3,
        .footer = {0xFF, 0xD9}, .footer_len = 2,
        .strategy = STRATEGY_SMART_JPEG, .max_size = 100ULL * 1024 * 1024, .min_size = JPEG_MIN_SIZE,
        .read_size = jpeg_smart_carve_size,
        .validate = jpeg_validate
    },
    {
        .name = "PNG", .extension = ".png",
        .header = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, .header_len = 8,
        .footer = {0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82}, .footer_len = 8,
        .strategy = STRATEGY_FOOTER, .max_size = 100ULL * 1024 * 1024, .min_size = PNG_MIN_SIZE,
    },
    {
        .name = "Video", .extension = ".mp4",
        .header = {0x66, 0x74, 0x79, 0x70}, .header_len = 4, .header_offset = 4,
        .strategy = STRATEGY_MAX_SIZE, .max_size = 64000ULL * 1024 * 1024, .min_size = MIN_FILE_SIZE,
        .read_size = mp4_read_size,
        .validate = mp4_validate
    },
    {
        .name = "Video (Smart)", .extension = ".mp4",
        .header = {0x00, 0x00, 0x00, 0x01, 0x67}, .header_len = 5,
        .strategy = STRATEGY_SMART_VIDEO, .max_size = 64000ULL * 1024 * 1024, .min_size = MIN_FILE_SIZE,
        .read_size = h264_smart_carve_size,
    }
};

#define NUM_SIGNATURES (sizeof(SIGNATURES) / sizeof(SIGNATURES[0]))

static int ReadChunk(const CarverContext* ctx, uint64_t byte_offset, uint8_t* buf, size_t buf_size, size_t* bytes_read) {
    if (LSEEK(ctx->fd, (off_t_64)byte_offset, SEEK_SET) < 0) return -1;
    ssize_t n = READ(ctx->fd, buf, (uint32_t)buf_size);
    if (n < 0) { *bytes_read = 0; return -1; }
    *bytes_read = (size_t)n;
    return 0;
}

#ifdef _WIN32
#define PATH_SEP_UNUSED '\\'
#else
#define PATH_SEP_UNUSED '/'
#endif

int ExtractFileRange(int fd, uint64_t start_byte, uint64_t file_size, const char* output_path) {
    FILE* out = fopen(output_path, "wb");
    if (!out) return -1;

    const size_t chunk_size = 4 * 1024 * 1024;
    uint8_t* buf = (uint8_t*)malloc(chunk_size);
    if (!buf) { fclose(out); return -1; }

    uint64_t remaining = file_size, pos = start_byte;
    while (remaining > 0) {
        size_t to_read = (remaining < chunk_size) ? (size_t)remaining : chunk_size;
        if (LSEEK(fd, (off_t_64)pos, SEEK_SET) < 0) break;
        ssize_t n = READ(fd, buf, (uint32_t)to_read);
        if (n <= 0) break;

        fwrite(buf, 1, n, out);
        remaining -= n;
        pos += n;
    }

    fclose(out);
    free(buf);
    return (remaining == 0) ? 0 : -1;
}

static uint64_t FindFooter(const CarverContext* ctx, uint64_t file_start, const FileSignature* sig) {
    const size_t scan_size = 2 * 1024 * 1024;
    const size_t overlap = (sig->footer_len > 0) ? (sig->footer_len - 1) : 0;
    uint8_t* read_buf = (uint8_t*)malloc(scan_size);
    uint8_t* scan_buf = (uint8_t*)malloc(scan_size + overlap);
    uint8_t tail[MAX_FOOTER_LEN - 1];
    size_t tail_len = 0;
    if (!read_buf || !scan_buf) {
        free(read_buf);
        free(scan_buf);
        return 0;
    }

    uint64_t pos = file_start;
    uint64_t end = file_start + sig->max_size;
    if (end > ctx->disk_size) end = ctx->disk_size;

    while (pos < end) {
        size_t n = 0;
        if (ReadChunk(ctx, pos, read_buf, scan_size, &n) != 0 || n == 0) break;

        size_t scan_len = tail_len + n;
        if (tail_len > 0) memcpy(scan_buf, tail, tail_len);
        memcpy(scan_buf + tail_len, read_buf, n);

        uint8_t* ptr = scan_buf;
        size_t search_len = scan_len;
        while (search_len >= sig->footer_len) {
            uint8_t* match = (uint8_t*)memchr(ptr, sig->footer[0], search_len - sig->footer_len + 1);
            if (!match) break;

            if (memcmp(match, sig->footer, sig->footer_len) == 0) {
                uint64_t found_pos = (pos - tail_len) + (uint64_t)(match - scan_buf) + sig->footer_len;
                free(read_buf);
                free(scan_buf);
                return found_pos;
            }
            ptr = match + 1;
            search_len = scan_len - (size_t)(ptr - scan_buf);
        }

        if (overlap > 0) {
            tail_len = (scan_len < overlap) ? scan_len : overlap;
            memcpy(tail, scan_buf + scan_len - tail_len, tail_len);
        } else {
            tail_len = 0;
        }

        pos += n;
    }
    free(read_buf);
    free(scan_buf);
    return 0;
}

int is_cluster_header(const uint8_t* buf, size_t len) {
    if (len < 8) return 0;
    for (size_t s = 0; s < NUM_SIGNATURES; s++) {
        const FileSignature* sig = &SIGNATURES[s];
        if (sig->header_len > 0 && sig->header_offset + sig->header_len <= len) {
            if (memcmp(buf + sig->header_offset, sig->header, sig->header_len) == 0) {
                // Potential header found, validate if it has a validator
                if (sig->validate) {
                    if (sig->validate(buf, len)) return 1;
                    else continue;
                }
                return 1;
            }
        }
    }
    return 0;
}

int CarveFilesWithProgress(int fd, uint64_t disk_size, uint32_t sector_size, const char* output_dir, void* context, CarveProgressCallback on_progress, CarveFileCallback on_file, volatile int* cancelled, double progress_start, double progress_end, const uint8_t* used_mask) {
    const uint32_t chunk_size = 4U * 1024U * 1024U;
    CarverContext ctx = { .fd = fd, .disk_size = disk_size, .sector_size = sector_size, .read_chunk = chunk_size };
    uint8_t* buf = (uint8_t*)malloc((size_t)chunk_size + 1024);
    int total_found = 0;
    uint64_t pos = 0;

    SignatureBucket signature_buckets[MAX_HEADER_LEN][256] = {{{0}}};
    uint8_t used_offsets[MAX_HEADER_LEN] = {0};
    size_t offsets[MAX_HEADER_LEN];
    size_t offset_count = 0;

    for (size_t s = 0; s < NUM_SIGNATURES; s++) {
        const FileSignature* sig = &SIGNATURES[s];
        if (sig->header_len == 0 || sig->header_offset >= MAX_HEADER_LEN) continue;

        if (!used_offsets[sig->header_offset]) {
            used_offsets[sig->header_offset] = 1;
            offsets[offset_count++] = sig->header_offset;
        }

        SignatureBucket* bucket = &signature_buckets[sig->header_offset][sig->header[0]];
        if (bucket->count < MAX_SIGNATURE_CANDIDATES) {
            bucket->items[bucket->count++] = sig;
        }
    }

    uint64_t last_progress_pos = 0;
    const uint64_t progress_interval = 4 * 1024 * 1024;

    if (on_progress) {
        on_progress(context, progress_start, 0, 0);
    }

    if (disk_size == 0 || !buf) {
        if (buf) free(buf);
        return 0;
    }

    while (pos < disk_size && (!cancelled || !*cancelled)) {
        size_t n = 0;
        ReadChunk(&ctx, pos, buf, chunk_size, &n);
        if (n == 0) break;

        int found_in_chunk = 0;
        for (size_t i = 0; i < n && !found_in_chunk; i++) {
            for (size_t oi = 0; oi < offset_count && !found_in_chunk; oi++) {
                size_t header_offset = offsets[oi];
                if (i + header_offset >= n) continue;

                SignatureBucket* bucket = &signature_buckets[header_offset][buf[i + header_offset]];
                if (bucket->count == 0) continue;

                // KIỂM TRA DEDUPLICATION: Nếu sector này đã được FS khôi phục, bỏ qua header tìm thấy ở đây
                uint64_t current_file_start = pos + i;
                int64_t current_sector = (int64_t)(current_file_start / sector_size);
                if (used_mask && (used_mask[current_sector >> 3] & (1 << (current_sector & 7)))) {
                    continue;
                }

                for (size_t b = 0; b < bucket->count; b++) {
                    const FileSignature* sig = bucket->items[b];
                    if (i + sig->header_offset + sig->header_len > n) continue;
                    if (memcmp(buf + i + sig->header_offset, sig->header, sig->header_len) != 0) continue;

                    if (sig->validate && !sig->validate(buf + i, n - i)) continue;

                    uint64_t file_start = pos + i;
                    uint64_t file_size = 0;
                    if (sig->strategy == STRATEGY_FOOTER) {
                        uint64_t end = FindFooter(&ctx, file_start, sig);
                        if (end > file_start) file_size = end - file_start;
                    } else if (sig->strategy == STRATEGY_MAX_SIZE || sig->strategy == STRATEGY_SMART_VIDEO || sig->strategy == STRATEGY_SMART_JPEG) {
                        if (sig->read_size) {
                            uint64_t s_field = sig->read_size(&ctx, file_start, buf + i, n - i);
                            if (s_field > 0) file_size = s_field;
                            else continue;
                        } else {
                            file_size = sig->max_size;
                        }
                    } else {
                        file_size = sig->max_size;
                    }

                    uint64_t min_size = sig->min_size ? sig->min_size : MIN_FILE_SIZE;
                    if (file_size >= min_size) {
                        char filename[256];
                        uint64_t sector_index = file_start / sector_size;
                        // Use GoPro style naming: GOPR[Sector].EXT
                        snprintf(filename, sizeof(filename), "GOPR%06llu%s", (unsigned long long)sector_index, sig->extension);

                        char carvedDir[1024];
                        snprintf(carvedDir, sizeof(carvedDir), "%s%cCARVED", output_dir, PATH_SEP);
                        mkdir_p(carvedDir);

                        char outPath[1024];
                        snprintf(outPath, sizeof(outPath), "%s%c%s", carvedDir, PATH_SEP, filename);

                        printf("DEBUG: Saving carved file to %s, size: %llu bytes\n", outPath, (unsigned long long)file_size);
                        if (ExtractFileRange(fd, file_start, file_size, outPath) == 0) {
                            if (on_file) on_file(context, sig->name, filename, "", file_size, sector_index);
                            total_found++;
                        }

                        pos = file_start + (file_size > 0 ? file_size : 1);
                        found_in_chunk = 1;
                    }
                }
            }
        }

        if (!found_in_chunk) {
            pos += (n > 64) ? (n - 64) : n;
        }

        if (pos - last_progress_pos >= progress_interval) {
            if (on_progress) {
                double phase_pct = (double)pos / disk_size * 100.0;
                double pct = progress_start + (phase_pct * (progress_end - progress_start) / 100.0);
                on_progress(context, pct, pos, 0);
            }
            last_progress_pos = pos;
        }
    }

    if (on_progress && (!cancelled || !*cancelled)) {
        on_progress(context, progress_end, disk_size, 0);
    }

    free(buf);
    return total_found;
}
