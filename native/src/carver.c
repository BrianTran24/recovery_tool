#include "carver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>

typedef enum {
    STRATEGY_FOOTER,
    STRATEGY_SIZE_FIELD,
    STRATEGY_MAX_SIZE
} CarveStrategy;

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
    uint64_t (*read_size)(const uint8_t* header_buf, size_t buf_len);
    int (*validate)(const uint8_t* buf, size_t len);
} FileSignature;

static uint64_t mp4_read_size(const uint8_t* buf, size_t len) {
    if (len < 8) return 0;
    uint32_t box_size = ((uint32_t)buf[0] << 24) | ((uint32_t)buf[1] << 16)
                        | ((uint32_t)buf[2] <<  8) |  (uint32_t)buf[3];
    if (box_size >= 8 && box_size < 1024 * 1024 * 1024)
        return (uint64_t)box_size;
    return 0;
}

static int jpeg_validate(const uint8_t* buf, size_t len) {
    // JPEG header: FF D8 FF
    // Thường theo sau bởi E0 (JFIF) hoặc E1 (Exif)
    if (len < 8) return 0;
    if (buf[3] == 0xE0 || buf[3] == 0xE1 || buf[3] == 0xDB || buf[3] == 0xC0) {
        // Kiểm tra xem có dữ liệu thực sự phía sau không (không phải toàn 0 hoặc 0xFF)
        int non_zero = 0;
        for (int i = 4; i < 64 && i < (int)len; i++) {
            if (buf[i] != 0x00 && buf[i] != 0xFF) {
                non_zero = 1;
                break;
            }
        }
        return non_zero;
    }
    return 0;
}

static int mp4_validate(const uint8_t* buf, size_t len) {
    // MP4 header offset 4: 'ftyp'
    // Kiểm tra thêm một vài bytes sau ftyp
    if (len < 12) return 0;
    // ftyp thường có các sub-type như mp42, isom, avc1...
    // Nếu byte 8-11 không rỗng thì khả năng cao là valid
    if (buf[8] != 0 || buf[9] != 0) return 1;
    return 0;
}

static FileSignature SIGNATURES[] = {
    {
        .name = "JPEG", .extension = ".jpg",
        .header = {0xFF, 0xD8, 0xFF}, .header_len = 3,
        .footer = {0xFF, 0xD9}, .footer_len = 2,
        .strategy = STRATEGY_FOOTER, .max_size = 50ULL * 1024 * 1024,
        .validate = jpeg_validate
    },
    {
        .name = "PNG", .extension = ".png",
        .header = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, .header_len = 8,
        .footer = {0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82}, .footer_len = 8,
        .strategy = STRATEGY_FOOTER, .max_size = 50ULL * 1024 * 1024,
    },
    {
        .name = "MP4", .extension = ".mp4",
        .header = {0x66, 0x74, 0x79, 0x70}, .header_len = 4, .header_offset = 4,
        .strategy = STRATEGY_MAX_SIZE, .max_size = 500ULL * 1024 * 1024,
        .read_size = mp4_read_size,
        .validate = mp4_validate
    },
    {
        .name = "PDF", .extension = ".pdf",
        .header = {0x25, 0x50, 0x44, 0x46}, .header_len = 4,
        .footer = {0x25, 0x25, 0x45, 0x4F, 0x46}, .footer_len = 5,
        .strategy = STRATEGY_FOOTER, .max_size = 200ULL * 1024 * 1024,
    }
};

#define NUM_SIGNATURES (sizeof(SIGNATURES) / sizeof(SIGNATURES[0]))

typedef struct {
    int      fd;
    uint64_t disk_size;
    uint32_t sector_size;
    uint32_t read_chunk;
} CarverContext;

static int ReadChunk(const CarverContext* ctx, uint64_t byte_offset, uint8_t* buf, size_t buf_size, size_t* bytes_read) {
    if (lseek(ctx->fd, (off_t)byte_offset, SEEK_SET) < 0) return -1;
    ssize_t n = read(ctx->fd, buf, buf_size);
    if (n < 0) { *bytes_read = 0; return -1; }
    *bytes_read = (size_t)n;
    return 0;
}

int ExtractFileRange(int fd, uint64_t start_byte, uint64_t file_size, const char* output_path) {
    FILE* out = fopen(output_path, "wb");
    if (!out) return -1;

    const size_t chunk_size = 1024 * 1024;
    uint8_t* buf = (uint8_t*)malloc(chunk_size);
    if (!buf) { fclose(out); return -1; }

    uint64_t remaining = file_size, pos = start_byte;
    while (remaining > 0) {
        size_t to_read = (remaining < chunk_size) ? (size_t)remaining : chunk_size;
        if (lseek(fd, (off_t)pos, SEEK_SET) < 0) break;
        ssize_t n = read(fd, buf, to_read);
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
    uint8_t* buf = (uint8_t*)malloc(ctx->read_chunk);
    uint64_t pos = file_start;
    uint64_t end = file_start + sig->max_size;
    if (end > ctx->disk_size) end = ctx->disk_size;
    while (pos < end) {
        size_t n = 0;
        ReadChunk(ctx, pos, buf, ctx->read_chunk, &n);
        if (n == 0) break;
        for (size_t i = 0; i <= (n > sig->footer_len ? n - sig->footer_len : 0); i++) {
            if (memcmp(buf + i, sig->footer, sig->footer_len) == 0) {
                free(buf);
                return pos + i + sig->footer_len;
            }
        }
        pos += (n > sig->footer_len) ? (n - sig->footer_len) : n;
    }
    free(buf);
    return 0;
}

int CarveFilesWithProgress(int fd, uint64_t disk_size, uint32_t sector_size, void* context, CarveProgressCallback on_progress, CarveFileCallback on_file, volatile int* cancelled) {
    CarverContext ctx = { .fd = fd, .disk_size = disk_size, .sector_size = sector_size, .read_chunk = 1024 * 1024 };
    uint8_t* buf = (uint8_t*)malloc(ctx.read_chunk + 64);
    int total_found = 0;
    uint64_t pos = 0;

    uint64_t last_progress_pos = 0;
    const uint64_t progress_interval = 2 * 1024 * 1024;

    if (on_progress) {
        on_progress(context, 0.0, 0, 0);
    }

    if (disk_size == 0) {
        free(buf);
        return 0;
    }

    while (pos < disk_size && (!cancelled || !*cancelled)) {
        size_t n = 0;
        ReadChunk(&ctx, pos, buf, ctx.read_chunk, &n);
        if (n == 0) break;

        int found_in_chunk = 0;
        for (size_t i = 0; i < n; i++) {
            for (size_t s = 0; s < NUM_SIGNATURES; s++) {
                FileSignature* sig = &SIGNATURES[s];
                if (i + sig->header_offset + sig->header_len > n) continue;
                if (memcmp(buf + i + sig->header_offset, sig->header, sig->header_len) == 0) {

                    // Thêm bước validate để loại bỏ rác
                    if (sig->validate) {
                        if (!sig->validate(buf + i, n - i)) continue;
                    }

                    uint64_t file_start = pos + i;
                    uint64_t file_size = 0;
                    if (sig->strategy == STRATEGY_FOOTER) {
                        uint64_t end = FindFooter(&ctx, file_start, sig);
                        if (end > file_start) file_size = end - file_start;
                    } else if (sig->strategy == STRATEGY_MAX_SIZE) {
                        if (sig->read_size) {
                             uint64_t s_field = sig->read_size(buf + i, n - i);
                             if (s_field > 0) file_size = s_field;
                             else file_size = sig->max_size;
                        } else {
                            file_size = sig->max_size;
                        }
                    } else {
                        file_size = sig->max_size;
                    }

                    // Junk filtering: Kích thước tối thiểu
                    if (file_size >= MIN_FILE_SIZE) {
                        if (on_file) on_file(context, sig->name, "carved", file_size, file_start / sector_size);
                        total_found++;

                        // Nhảy qua vùng đã tìm thấy
                        pos = file_start + (file_size > 0 ? file_size : 1);
                        found_in_chunk = 1;
                        break;
                    }
                }
            }
            if (found_in_chunk) break;
        }

        if (!found_in_chunk) {
            pos += (n > 64) ? (n - 64) : n;
        }

        if (pos - last_progress_pos >= progress_interval) {
            if (on_progress) {
                on_progress(context, (double)pos / disk_size * 100.0, pos, 0);
            }
            last_progress_pos = pos;
        }
    }

    if (on_progress && (!cancelled || !*cancelled)) {
        on_progress(context, 100.0, disk_size, 0);
    }

    free(buf);
    return total_found;
}
