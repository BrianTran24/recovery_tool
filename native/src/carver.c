#include "carver.h"
#include "platform_config.h"
#include "video_repair.h"
#include "fragment_validator.h"
#include "signature_registry.h"
#include "device_handlers.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <math.h>

static SignatureRegistry g_registry;
static int g_registry_init = 0;

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

// Signature definitions are now in signature_registry.c

static int file_exists(const char* path) {
    FILE* f = fopen(path, "rb");
    if (!f) return 0;
    fclose(f);
    return 1;
}

static int64_t file_size_of(const char* path) {
    FILE* f = fopen(path, "rb");
    if (!f) return -1;
#ifdef _WIN32
    _fseeki64(f, 0, SEEK_END);
    int64_t s = _ftelli64(f);
#else
    fseeko(f, 0, SEEK_END);
    int64_t s = (int64_t)ftello(f);
#endif
    fclose(f);
    return s;
}

static void make_unique_path(char* path, size_t pathSize) {
    char dir[1024];
    char leaf[256];
    char stem[256];
    char ext[128];

    if (!path || pathSize == 0 || !file_exists(path)) return;

    const char* lastSep = strrchr(path, PATH_SEP);
    if (lastSep) {
        size_t dirLen = (size_t)(lastSep - path);
        if (dirLen >= sizeof(dir)) dirLen = sizeof(dir) - 1;
        memcpy(dir, path, dirLen);
        dir[dirLen] = '\0';
        snprintf(leaf, sizeof(leaf), "%s", lastSep + 1);
    } else {
        dir[0] = '\0';
        snprintf(leaf, sizeof(leaf), "%s", path);
    }

    const char* lastDot = strrchr(leaf, '.');
    if (lastDot && lastDot != leaf) {
        size_t stemLen = (size_t)(lastDot - leaf);
        if (stemLen >= sizeof(stem)) stemLen = sizeof(stem) - 1;
        memcpy(stem, leaf, stemLen);
        stem[stemLen] = '\0';
        snprintf(ext, sizeof(ext), "%s", lastDot);
    } else {
        snprintf(stem, sizeof(stem), "%s", leaf);
        ext[0] = '\0';
    }

    for (unsigned i = 1; i < 10000; i++) {
        char candidate[2048];
        if (dir[0]) {
            if (ext[0]) snprintf(candidate, sizeof(candidate), "%s%c%s_%u%s", dir, PATH_SEP, stem, i, ext);
            else snprintf(candidate, sizeof(candidate), "%s%c%s_%u", dir, PATH_SEP, stem, i);
        } else if (ext[0]) {
            snprintf(candidate, sizeof(candidate), "%s_%u%s", stem, i, ext);
        } else {
            snprintf(candidate, sizeof(candidate), "%s_%u", stem, i);
        }
        if (!file_exists(candidate)) {
            snprintf(path, pathSize, "%s", candidate);
            return;
        }
    }
}

static uint16_t read_be16(const uint8_t* p) {
    return (uint16_t)(((uint16_t)p[0] << 8) | p[1]);
}

static uint32_t read_be32(const uint8_t* p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

static uint64_t read_be64(const uint8_t* p) {
    return ((uint64_t)read_be32(p) << 32) | (uint64_t)read_be32(p + 4);
}

// === HEVC (H.265) SPS Parser to distinguish GoPro Main vs LRV ===

typedef struct {
    const uint8_t* buf;
    size_t len;
    size_t pos; // bit position
} BitStream;

static uint32_t bs_read_bit(BitStream* bs) {
    if (bs->pos / 8 >= bs->len) return 0;
    uint32_t bit = (bs->buf[bs->pos / 8] >> (7 - (bs->pos % 8))) & 1;
    bs->pos++;
    return bit;
}

static uint32_t bs_read_bits(BitStream* bs, int n) {
    uint32_t val = 0;
    for (int i = 0; i < n; i++) val = (val << 1) | bs_read_bit(bs);
    return val;
}

static uint32_t bs_read_ue(BitStream* bs) {
    int zeros = 0;
    while (bs_read_bit(bs) == 0 && zeros < 32) zeros++;
    if (zeros == 0) return 0;
    return (uint32_t)((1 << zeros) - 1 + bs_read_bits(bs, zeros));
}

static void bs_skip_profile_tier_level(BitStream* bs, int max_sub_layers) {
    bs_read_bits(bs, 2); // general_profile_space
    bs_read_bit(bs);     // general_tier_flag
    bs_read_bits(bs, 5); // general_profile_idc
    bs->pos += 32;       // general_profile_compatibility_flag[32]
    bs_read_bit(bs);     // general_progressive_source_flag
    bs_read_bit(bs);     // general_interlaced_source_flag
    bs_read_bit(bs);     // general_non_packed_constraint_flag
    bs_read_bit(bs);     // general_frame_only_constraint_flag
    bs->pos += 44;       // constraint flags + reserved
    bs_read_bits(bs, 8); // general_level_idc

    uint8_t sub_layer_profile_present_flag[8];
    uint8_t sub_layer_level_present_flag[8];
    for (int i = 0; i < max_sub_layers; i++) {
        sub_layer_profile_present_flag[i] = (uint8_t)bs_read_bit(bs);
        sub_layer_level_present_flag[i] = (uint8_t)bs_read_bit(bs);
    }
    if (max_sub_layers > 0) bs->pos += (8 - max_sub_layers) * 2;

    for (int i = 0; i < max_sub_layers; i++) {
        if (sub_layer_profile_present_flag[i]) bs->pos += 88;
        if (sub_layer_level_present_flag[i]) bs->pos += 8;
    }
}

int parse_hevc_sps_dims(const uint8_t* sps, size_t len, int* w, int* h) {
    if (len < 20) return 0;
    BitStream bs = { .buf = sps, .len = len, .pos = 0 };

    // HEVC NAL Header is 2 bytes: F(1) + Type(6) + LayerId(6) + Tid(3)
    // For SPS, Type = 33 (0x21). Byte 1: 0x42, Byte 2: 0x01
    if (bs_read_bits(&bs, 1) != 0) return 0; // forbidden_zero_bit
    if (bs_read_bits(&bs, 6) != 33) return 0; // sps_nal_unit_type
    bs_read_bits(&bs, 6); // layer_id
    bs_read_bits(&bs, 3); // temporal_id_plus1

    bs_read_bits(&bs, 4); // sps_video_parameter_set_id
    int max_sub_layers = bs_read_bits(&bs, 3);
    bs_read_bit(&bs); // sps_temporal_id_nesting_flag

    bs_skip_profile_tier_level(&bs, max_sub_layers);

    bs_read_ue(&bs); // sps_seq_parameter_set_id
    uint32_t chroma = bs_read_ue(&bs);
    if (chroma == 3) bs_read_bit(&bs);

    *w = (int)bs_read_ue(&bs);
    *h = (int)bs_read_ue(&bs);

    return (*w > 0 && *h > 0);
}

typedef enum {
    GOPRO_MAIN,
    GOPRO_LRV,
    GOPRO_METADATA,
    GOPRO_UNKNOWN
} GoProClusterType;

static GoProClusterType classify_gopro_cluster(const uint8_t* buf, size_t len) {
    // 1. Check for Metadata (GoPro uses DEVC/GPMF)
    if (len >= 12) {
        if (memcmp(buf, "DEVC", 4) == 0 || memcmp(buf + 8, "DEVC", 4) == 0) return GOPRO_METADATA;
    }

    // 2. Search for HEVC SPS NAL unit to distinguish resolution
    // Standard Start Code: 00 00 01 (3 bytes) or 00 00 00 01 (4 bytes)
    for (size_t i = 0; i < len - 32; i++) {
        if (buf[i] == 0x00 && buf[i+1] == 0x00 && (buf[i+2] == 0x01 || (buf[i+2] == 0x00 && buf[i+3] == 0x01))) {
            size_t start_code_len = (buf[i+2] == 0x01) ? 3 : 4;
            const uint8_t* nalu = buf + i + start_code_len;
            // Byte 1 of HEVC NAL header: Forbidden(1) + Type(6) + LayerId_High(1)
            // SPS Type is 33 (0x21). Byte 1 = (33 << 1) = 66 (0x42)
            if (nalu[0] == 0x42 && nalu[1] == 0x01) {
                int w = 0, h = 0;
                if (parse_hevc_sps_dims(nalu, len - (i + start_code_len), &w, &h)) {
                    if (w >= 1920) return GOPRO_MAIN;
                    if (w > 0 && w <= 1280) return GOPRO_LRV;
                }
            }
        }
    }

    // 3. Check for ftyp headers
    if (len >= 16 && memcmp(buf + 4, "ftyp", 4) == 0) {
        // GoPro Main often has "gopro" or "mp42"
        if (memcmp(buf + 8, "gopro", 5) == 0) return GOPRO_MAIN;
    }

    return GOPRO_UNKNOWN;
}

static int read_prefix(const CarverContext* ctx, uint64_t file_start, uint8_t* buf, size_t want, size_t* got) {
    if (LSEEK(ctx->fd, (off_t_64)file_start, SEEK_SET) < 0) return -1;
    ssize_t n = READ(ctx->fd, buf, (uint32_t)want);
    if (n < 0) return -1;
    if (got) *got = (size_t)n;
    return 0;
}

static int format_unix_time_name(time_t value, char* out, size_t outSize) {
    struct tm tmv;
#ifdef _WIN32
    if (gmtime_s(&tmv, &value) != 0) return 0;
#else
    if (!gmtime_r(&value, &tmv)) return 0;
#endif
    return strftime(out, outSize, "%Y%m%d_%H%M%S", &tmv) > 0;
}

static int parse_exif_datetime(const char* raw, char* out, size_t outSize) {
    int y, m, d, hh, mm, ss;
    if (sscanf(raw, "%4d:%2d:%2d %2d:%2d:%2d", &y, &m, &d, &hh, &mm, &ss) == 6) {
        if (y >= 1980 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
            snprintf(out, outSize, "%04d%02d%02d_%02d%02d%02d", y, m, d, hh, mm, ss);
            return 1;
        }
    }
    return 0;
}

static int jpeg_extract_ascii_datetime_from_ptr(const uint8_t* src, uint32_t count, char* out, size_t outSize) {
    size_t copy = 0;
    char raw[64];

    if (count == 0) return 0;
    if (count > sizeof(raw) - 1) count = (uint32_t)(sizeof(raw) - 1);

    memcpy(raw, src, count);
    copy = count;
    raw[copy] = '\0';
    return parse_exif_datetime(raw, out, outSize);
}

static int jpeg_parse_ifd(const uint8_t* tiff, size_t tiffLen, uint32_t ifdOffset, int little, char* out, size_t outSize) {
    if (ifdOffset + 2 > tiffLen) return 0;
    uint16_t entries = little ? (uint16_t)(tiff[ifdOffset] | (tiff[ifdOffset + 1] << 8)) : read_be16(tiff + ifdOffset);
    size_t pos = ifdOffset + 2;
    uint32_t exifIfdOffset = 0;

    for (uint16_t i = 0; i < entries; i++) {
        if (pos + 12 > tiffLen) break;
        const uint8_t* e = tiff + pos;
        uint16_t tag = little ? (uint16_t)(e[0] | (e[1] << 8)) : read_be16(e);
        uint16_t type = little ? (uint16_t)(e[2] | (e[3] << 8)) : read_be16(e + 2);
        uint32_t count = little ? (uint32_t)e[4] | ((uint32_t)e[5] << 8) | ((uint32_t)e[6] << 16) | ((uint32_t)e[7] << 24) : read_be32(e + 4);
        uint32_t value = little ? (uint32_t)e[8] | ((uint32_t)e[9] << 8) | ((uint32_t)e[10] << 16) | ((uint32_t)e[11] << 24) : read_be32(e + 8);

        if ((tag == 0x9003 || tag == 0x9004 || tag == 0x0132) && type == 2 && count > 0) {
            if (count <= 4) {
                if (jpeg_extract_ascii_datetime_from_ptr(e + 8, count, out, outSize)) return 1;
            } else if (value < tiffLen && value + count <= tiffLen) {
                if (jpeg_extract_ascii_datetime_from_ptr(tiff + value, count, out, outSize)) return 1;
            }
        } else if (tag == 0x8769 && count > 0) {
            exifIfdOffset = value;
        }
        pos += 12;
    }

    if (exifIfdOffset > 0 && exifIfdOffset + 2 <= tiffLen) {
        entries = little ? (uint16_t)(tiff[exifIfdOffset] | (tiff[exifIfdOffset + 1] << 8)) : read_be16(tiff + exifIfdOffset);
        pos = exifIfdOffset + 2;
        for (uint16_t i = 0; i < entries; i++) {
            if (pos + 12 > tiffLen) break;
            const uint8_t* e = tiff + pos;
            uint16_t tag = little ? (uint16_t)(e[0] | (e[1] << 8)) : read_be16(e);
            uint16_t type = little ? (uint16_t)(e[2] | (e[3] << 8)) : read_be16(e + 2);
            uint32_t count = little ? (uint32_t)e[4] | ((uint32_t)e[5] << 8) | ((uint32_t)e[6] << 16) | ((uint32_t)e[7] << 24) : read_be32(e + 4);
            uint32_t value = little ? (uint32_t)e[8] | ((uint32_t)e[9] << 8) | ((uint32_t)e[10] << 16) | ((uint32_t)e[11] << 24) : read_be32(e + 8);
            if ((tag == 0x9003 || tag == 0x9004 || tag == 0x0132) && type == 2 && count > 0) {
                if (count <= 4) {
                    if (jpeg_extract_ascii_datetime_from_ptr(e + 8, count, out, outSize)) return 1;
                } else if (value < tiffLen && value + count <= tiffLen) {
                    if (jpeg_extract_ascii_datetime_from_ptr(tiff + value, count, out, outSize)) return 1;
                }
            }
            pos += 12;
        }
    }

    return 0;
}

static int extract_jpeg_metadata(const CarverContext* ctx, uint64_t file_start, char* out, size_t outSize) {
    size_t want = 64 * 1024;
    uint8_t* buf = (uint8_t*)malloc(want);
    size_t got = 0;

    if (!buf) return 0;
    if (read_prefix(ctx, file_start, buf, want, &got) != 0 || got < 4) {
        free(buf);
        return 0;
    }

    size_t pos = 2;
    while (pos + 4 <= got) {
        if (buf[pos] != 0xFF) {
            pos++;
            continue;
        }
        while (pos < got && buf[pos] == 0xFF) pos++;
        if (pos + 1 >= got) break;

        uint8_t marker = buf[pos];
        if (marker == 0xD9 || marker == 0xDA) break;
        if (pos < 2) break;
        if (pos + 2 > got) break;

        if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
            pos += 1;
            continue;
        }

        if (pos + 4 > got) break;
        uint16_t segLen = read_be16(buf + pos + 1);
        if (segLen < 2 || pos + 1 + segLen > got) break;

        if (marker == 0xE1 && segLen >= 8 && memcmp(buf + pos + 4, "Exif\0\0", 6) == 0) {
            const uint8_t* tiff = buf + pos + 10;
            size_t tiffLen = segLen - 8;
            if (tiffLen >= 8) {
                int little = (tiff[0] == 'I' && tiff[1] == 'I');
                if ((little || (tiff[0] == 'M' && tiff[1] == 'M')) && ((little && tiff[2] == 0x2A && tiff[3] == 0x00) || (!little && tiff[2] == 0x00 && tiff[3] == 0x2A))) {
                    uint32_t ifd0 = little ? (uint32_t)tiff[4] | ((uint32_t)tiff[5] << 8) | ((uint32_t)tiff[6] << 16) | ((uint32_t)tiff[7] << 24) : read_be32(tiff + 4);
                    if (ifd0 + 8 <= tiffLen && jpeg_parse_ifd(tiff, tiffLen, ifd0, little, out, outSize)) {
                        free(buf);
                        return 1;
                    }
                }
            }
        }

        pos += (size_t)segLen + 3;
    }

    free(buf);
    return 0;
}

static int mp4_find_box(const uint8_t* buf, size_t len, const char* target, size_t* outPos, size_t* outSize) {
    size_t pos = 0;

    while (pos + 8 <= len) {
        uint64_t boxSize = read_be32(buf + pos);
        char type[5] = { (char)buf[pos + 4], (char)buf[pos + 5], (char)buf[pos + 6], (char)buf[pos + 7], 0 };
        size_t header = 8;

        if (boxSize == 1) {
            if (pos + 16 > len) return 0;
            boxSize = read_be64(buf + pos + 8);
            header = 16;
        } else if (boxSize == 0) {
            boxSize = len - pos;
        }

        if (boxSize < header || pos + boxSize > len) return 0;

        if (memcmp(type, target, 4) == 0) {
            if (outPos) *outPos = pos;
            if (outSize) *outSize = (size_t)boxSize;
            return 1;
        }

        if (memcmp(type, "moov", 4) == 0 || memcmp(type, "trak", 4) == 0 || memcmp(type, "udta", 4) == 0 || memcmp(type, "mdia", 4) == 0 || memcmp(type, "meta", 4) == 0) {
            size_t childStart = pos + header;
            if (memcmp(type, "meta", 4) == 0 && childStart + 4 <= pos + boxSize) childStart += 4;
            if (childStart < pos + boxSize) {
                size_t childLen = (size_t)((pos + boxSize) - childStart);
                size_t relPos = 0, relSize = 0;
                if (mp4_find_box(buf + childStart, childLen, target, &relPos, &relSize)) {
                    if (outPos) *outPos = childStart + relPos;
                    if (outSize) *outSize = relSize;
                    return 1;
                }
            }
        }

        pos += (size_t)boxSize;
    }

    return 0;
}

static int extract_mp4_metadata(const CarverContext* ctx, uint64_t file_start, uint64_t file_size, char* out, size_t outSize) {
    size_t want = (file_size < (4ULL * 1024ULL * 1024ULL)) ? (size_t)file_size : (size_t)(4ULL * 1024ULL * 1024ULL);
    uint8_t* buf = (uint8_t*)malloc(want);
    size_t got = 0;

    if (!buf) return 0;
    if (want < 32 || read_prefix(ctx, file_start, buf, want, &got) != 0 || got < 32) {
        free(buf);
        return 0;
    }

    size_t moovPos = 0, moovSize = 0;
    if (!mp4_find_box(buf, got, "moov", &moovPos, &moovSize)) {
        free(buf);
        return 0;
    }

    size_t mvhdPos = 0, mvhdSize = 0;
    if (!mp4_find_box(buf + moovPos, moovSize, "mvhd", &mvhdPos, &mvhdSize) || mvhdPos + 24 > moovSize) {
        free(buf);
        return 0;
    }

    const uint8_t* mvhd = buf + moovPos + mvhdPos;
    uint8_t version = mvhd[8];
    uint64_t creation = 0;
    if (version == 1 && mvhdPos + 32 <= moovSize) {
        creation = read_be64(mvhd + 12);
    } else {
        creation = (uint64_t)read_be32(mvhd + 12);
    }

    if (creation < 2082844800ULL) {
        free(buf);
        return 0;
    }

    time_t unixTime = (time_t)(creation - 2082844800ULL);
    int ok = format_unix_time_name(unixTime, out, outSize);
    free(buf);
    return ok;
}

static int extract_internal_metadata(const CarverContext* ctx, const FileSignature* sig, uint64_t file_start, uint64_t file_size, char* out, size_t outSize) {
    if (!sig || !out || outSize == 0) return 0;

    if (sig->extension && strcmp(sig->extension, ".jpg") == 0) {
        return extract_jpeg_metadata(ctx, file_start, out, outSize);
    }
    if (sig->extension && strcmp(sig->extension, ".mp4") == 0) {
        return extract_mp4_metadata(ctx, file_start, file_size, out, outSize);
    }

    return 0;
}

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

// Quét tiến tìm box MP4 hợp lệ kế tiếp (dùng để nhảy qua khoảng phân mảnh).
// Trả về vị trí tuyệt đối của box, hoặc 0 nếu không thấy trong cửa sổ.
static uint64_t mp4_find_next_box(const CarverContext* ctx, uint64_t from, uint64_t max_scan) {
    static const char* types[] = { "moov", "mdat", "free", "skip", "wide", "ftyp", "uuid" };
    uint8_t win[65536];
    uint64_t pos = from;
    uint64_t end = from + max_scan;
    if (end > ctx->disk_size) end = ctx->disk_size;

    while (pos + 8 <= end) {
        size_t want = sizeof(win);
        if (pos + want > end) want = (size_t)(end - pos);
        if (LSEEK(ctx->fd, (off_t_64)pos, SEEK_SET) < 0) break;
        ssize_t n = READ(ctx->fd, win, (uint32_t)want);
        if (n < 8) break;

        for (size_t i = 0; i + 8 <= (size_t)n; i++) {
            const uint8_t* t = win + i + 4;
            for (size_t k = 0; k < sizeof(types) / sizeof(types[0]); k++) {
                if (memcmp(t, types[k], 4) == 0) {
                    uint32_t bs = read_be32(win + i);
                    if (bs >= 8 && (uint64_t)bs <= ctx->disk_size) return pos + i;
                    if (bs == 1) return pos + i; // 64-bit size box
                }
            }
        }
        pos += (n > 8) ? (size_t)(n - 7) : (size_t)n; // chồng lấn 7 byte
    }
    return 0;
}

uint64_t mp4_read_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len, int* out_has_moov) {
    uint64_t pos = file_start;
    uint64_t total_size = 0;
    uint8_t box_header[16];
    int found_moov = 0;
    int found_mdat = 0;
    int frag_jumps = 0;

    // Duyệt qua các box của MP4 trực tiếp trên đĩa để tìm kích thước thực
    for (int i = 0; i < 400; i++) {
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

        // #5 XỬ LÝ PHÂN MẢNH: box không hợp lệ / kích thước sai → thử nhảy qua khoảng
        // phân mảnh để tìm box hợp lệ kế tiếp (đặc biệt hữu ích khi moov nằm cuối).
        if (!valid_type || (box_size < 8 && box_size != 0) || box_size > ctx->disk_size) {
            if (!found_moov && frag_jumps < 8) {
                uint64_t nxt = mp4_find_next_box(ctx, pos + 4, 128ULL * 1024 * 1024);
                if (nxt > pos) {
                    frag_jumps++;
                    pos = nxt;
                    total_size = pos - file_start;
                    continue;
                }
            }
            break;
        }

        if (strcmp(type, "moov") == 0) found_moov = 1;
        if (strcmp(type, "mdat") == 0) found_mdat = 1;

        if (box_size == 0) { // Box kéo dài đến hết file
            pos = ctx->disk_size; // Chấp nhận box đến hết đĩa
            total_size = pos - file_start;
            break;
        }

        pos += box_size;
        total_size = pos - file_start;

        // Nếu tìm thấy moov, khả năng cao là đã đủ thông tin để play
        if (found_moov && found_mdat && total_size > 1024 * 1024) {
            if (out_has_moov) *out_has_moov = 1;
            return total_size;
        }
        if (total_size > 20000ULL * 1024 * 1024) break; // Tăng giới hạn lên 20GB cho video 4K
    }

    if (out_has_moov) *out_has_moov = found_moov;

    // CẢI TIẾN: Trả về kích thước ngay cả khi thiếu moov (nhưng có mdat)
    // để cứu được dữ liệu thô của các video bị lỗi/crashed
    if (found_moov || found_mdat) return total_size;
    return 0;
}

// SMART CARVER: Quét NAL units để xử lý phân mảnh
// Logic: Tìm các start code 00 00 00 01 và kiểm tra NAL type
// Nếu gặp vùng dữ liệu lạ, thử tìm start code tiếp theo trong phạm vi 1MB
uint64_t h264_smart_carve_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len, int* out_has_moov) {
    if (out_has_moov) *out_has_moov = 0;
    uint64_t pos = file_start;
    uint64_t last_valid_pos = file_start;
    uint8_t chunk[1024 * 64];
    const size_t chunk_size = sizeof(chunk);

    H264Context h264_ctx = {0};
    int last_frame_num = -1;
    int has_sps = 0;
    int continuous_errors = 0;

    // Look for SPS in the first chunk to initialize validator
    for (size_t i = 0; i < len - 4; i++) {
        if (buf[i] == 0x00 && buf[i+1] == 0x00 && buf[i+2] == 0x01 && (buf[i+3] & 0x1F) == 7) {
            parse_h264_sps(buf + i + 3, 64, &h264_ctx);
            has_sps = 1;
            break;
        }
    }

    uint64_t max_scan = 4000ULL * 1024 * 1024; // 4GB max for smart carve
    if (pos + max_scan > ctx->disk_size) max_scan = ctx->disk_size - pos;

    while (pos < file_start + max_scan) {
        if (LSEEK(ctx->fd, (off_t_64)pos, SEEK_SET) < 0) break;
        ssize_t n = READ(ctx->fd, chunk, (uint32_t)chunk_size);
        if (n < 16) break;

        int valid = 1;
        if (has_sps) {
            valid = validate_h264_fragment(&h264_ctx, chunk, (size_t)n, &last_frame_num);
        }

        if (valid) {
            last_valid_pos = pos + n;
            continuous_errors = 0;
        } else {
            continuous_errors++;
            // If fragmented, try to find the next valid NAL
            if (continuous_errors > 4) { // ~256KB of invalid data
                uint64_t search_pos = pos + n;
                int found_next = 0;
                for (int j = 0; j < 1024; j++) { // Search up to 64MB ahead
                    uint8_t probe[4096];
                    if (LSEEK(ctx->fd, search_pos, SEEK_SET) < 0) break;
                    if (READ(ctx->fd, probe, 4096) < 16) break;

                    if (validate_h264_fragment(&h264_ctx, probe, 4096, &last_frame_num)) {
                        pos = search_pos;
                        found_next = 1;
                        break;
                    }
                    search_pos += 64 * 1024;
                }
                if (!found_next) break;
                continue;
            }
        }
        pos += n;
    }

    return last_valid_pos - file_start;
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

uint64_t jpeg_smart_carve_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len, int* out_has_moov) {
    if (out_has_moov) *out_has_moov = 0;
    uint64_t pos = file_start;
    uint8_t marker_buf[4];

    JPEGContext jpeg_ctx = {0};
    parse_jpeg_header_info(buf, len, &jpeg_ctx);

    // 1. Skip FF D8
    pos += 2;
    // ... same marker parsing as before ...
    while (pos + 4 < ctx->disk_size) {
        if (LSEEK(ctx->fd, (off_t_64)pos, SEEK_SET) < 0) break;
        if (READ(ctx->fd, marker_buf, 4) != 4) break;
        if (marker_buf[0] != 0xFF) break;
        uint8_t marker = marker_buf[1];
        if (marker == 0xDA) { pos += 2; break; }
        if (marker == 0xD8) { pos += 2; continue; }
        if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) { pos += 2; continue; }
        uint32_t marker_len = (marker_buf[2] << 8) | marker_buf[3];
        pos += marker_len + 2;
    }

    uint64_t last_valid_pos = pos;
    uint8_t chunk[16 * 1024];
    int continuous_invalid = 0;

    while (pos < file_start + (100ULL * 1024 * 1024)) { // Up to 100MB for 4K/RAW photos
        if (LSEEK(ctx->fd, (off_t_64)pos, SEEK_SET) < 0) break;
        ssize_t n = READ(ctx->fd, chunk, sizeof(chunk));
        if (n < 64) break;

        if (validate_jpeg_fragment(&jpeg_ctx, chunk, (size_t)n)) {
            continuous_invalid = 0;
            last_valid_pos = pos + (uint64_t)n;

            // Look for EOI
            for (size_t i = 0; i < (size_t)n - 1; i++) {
                if (chunk[i] == 0xFF && chunk[i+1] == 0xD9) {
                    return pos + (uint64_t)i + 2 - file_start;
                }
            }
        } else {
            continuous_invalid++;
            if (continuous_invalid > 8) { // 128KB invalid
                // Try to find next fragment
                uint64_t search_pos = pos + n;
                int found_next = 0;
                for (int j = 0; j < 512; j++) { // Search 8MB ahead
                    uint8_t probe[4096];
                    if (LSEEK(ctx->fd, search_pos, SEEK_SET) < 0) break;
                    if (READ(ctx->fd, probe, 4096) < 64) break;
                    if (validate_jpeg_fragment(&jpeg_ctx, probe, 4096)) {
                        pos = search_pos;
                        found_next = 1;
                        break;
                    }
                    search_pos += 16 * 1024;
                }
                if (!found_next) break;
                continue;
            }
        }
        pos += (uint64_t)n;
    }
    return last_valid_pos - file_start;
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

int jpeg_validate(const uint8_t* buf, size_t len) {
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


int mp4_validate(const uint8_t* buf, size_t len) {
    if (len < 32) return 0;
    // Kiểm tra ftyp brand (phải là ký tự in được)
    for (int i = 8; i < 12; i++) {
        if (buf[i] != 0 && (buf[i] < 32 || buf[i] > 126)) return 0;
    }
    // Brand không được rỗng
    if (buf[8] == 0 && buf[9] == 0 && buf[10] == 0 && buf[11] == 0) return 0;

    // Kiểm tra cấu trúc box đầu tiên (ftyp)
    uint32_t ftypSize = read_be32(buf);
    if (ftypSize < 8 || ftypSize > 1024) return 0; // ftyp thường nhỏ

    return 1;
}

// SIGNATURES moved to signature_registry.c

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
    if (!g_registry_init) {
        init_signature_registry(&g_registry);
        g_registry_init = 1;
    }
    for (size_t s = 0; s < g_registry.count; s++) {
        const FileSignature* sig = &g_registry.signatures[s];
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

int CarveFilesWithProgress(int fd, uint64_t disk_size, uint32_t sector_size, const char* output_dir, void* context, CarveProgressCallback on_progress, CarveFileCallback on_file, volatile int* cancelled, volatile int* paused, double progress_start, double progress_end, const uint8_t* used_mask, const char* reference_video) {
    if (!g_registry_init) {
        init_signature_registry(&g_registry);
        g_registry_init = 1;
    }

    const uint32_t chunk_size = 4U * 1024U * 1024U;
    CarverContext ctx = { .fd = fd, .disk_size = disk_size, .sector_size = sector_size, .read_chunk = chunk_size };
    uint8_t* buf = (uint8_t*)malloc((size_t)chunk_size + 1024);
    int total_found = 0;
    uint64_t pos = 0;

    SignatureBucket signature_buckets[MAX_HEADER_LEN][256] = {{{0}}};
    uint8_t used_offsets[MAX_HEADER_LEN] = {0};
    size_t offsets[MAX_HEADER_LEN];
    size_t offset_count = 0;

    for (size_t s = 0; s < g_registry.count; s++) {
        const FileSignature* sig = &g_registry.signatures[s];
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
    int64_t last_progress_ms = GetTimeMs();
    const uint64_t progress_interval = 4 * 1024 * 1024;

    if (on_progress) {
        on_progress(context, progress_start, 0, 0);
    }

    if (disk_size == 0 || !buf) {
        if (buf) free(buf);
        return 0;
    }

    while (pos < disk_size && (!cancelled || !*cancelled)) {
        while (paused && *paused && (!cancelled || !*cancelled)) SLEEP_MS(100);
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
                    int has_moov = 0;
                    if (sig->strategy == STRATEGY_FOOTER) {
                        uint64_t end = FindFooter(&ctx, file_start, sig);
                        if (end > file_start) file_size = end - file_start;
                    } else if (sig->strategy == STRATEGY_MAX_SIZE || sig->strategy == STRATEGY_SMART_VIDEO || sig->strategy == STRATEGY_SMART_JPEG || sig->strategy == STRATEGY_SIZE_FIELD) {
                        if (sig->read_size) {
                            uint64_t s_field = sig->read_size(&ctx, file_start, buf + i, n - i, &has_moov);
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
                        char nameStem[128];
                        uint64_t sector_index = file_start / sector_size;
                        if (extract_internal_metadata(&ctx, sig, file_start, file_size, nameStem, sizeof(nameStem))) {
                            snprintf(filename, sizeof(filename), "%s%s", nameStem, sig->extension ? sig->extension : "");
                        } else {
                            // Use GoPro style naming as the final fallback
                            snprintf(filename, sizeof(filename), "GOPR%06llu%s", (unsigned long long)sector_index, sig->extension ? sig->extension : "");
                        }

                        char carvedDir[1024];
                        snprintf(carvedDir, sizeof(carvedDir), "%s%cCARVED", output_dir, PATH_SEP);
                        mkdir_p(carvedDir);

                        char outPath[1024];
                        snprintf(outPath, sizeof(outPath), "%s%c%s", carvedDir, PATH_SEP, filename);
                        make_unique_path(outPath, sizeof(outPath));

                        printf("DEBUG: Saving carved file to %s, size: %llu bytes\n", outPath, (unsigned long long)file_size);

                        int extract_ok = -1;
                        uint64_t final_size = file_size;

                        int is_mp4 = (sig->extension && strcmp(sig->extension, ".mp4") == 0);
                        int device_id = DEVICE_NONE;
                        if (is_mp4) {
                            if (is_gopro_device(buf + i, n - i)) device_id = DEVICE_GOPRO;
                            else if (is_dji_device(buf + i, n - i)) device_id = DEVICE_DJI;
                        }

                        if (is_mp4 && !has_moov) {
                            // #4/#7 Video thiếu `moov` → không mở được. Thử repair tự động
                            // bằng video tham chiếu (frame-rebuild, fallback best-effort).
                            int repaired = 0;
                            if (reference_video && reference_video[0]) {
                                char brokenPath[1200];
                                snprintf(brokenPath, sizeof(brokenPath), "%s.broken", outPath);
                                if (ExtractFileRange(fd, file_start, file_size, brokenPath) == 0) {
                                    if (RepairVideo(brokenPath, reference_video, outPath) == 0) {
                                        repaired = 1;
                                        extract_ok = 0;
                                        int64_t rsz = file_size_of(outPath);
                                        if (rsz > 0) final_size = (uint64_t)rsz;
                                    }
                                    remove(brokenPath);
                                }
                            }
                            if (!repaired) {
                                // Không repair được → lưu dữ liệu thô vào NEEDS_REPAIR để cứu.
                                char needDir[1200];
                                snprintf(needDir, sizeof(needDir), "%s%cNEEDS_REPAIR", carvedDir, PATH_SEP);
                                mkdir_p(needDir);
                                const char* leaf = strrchr(outPath, PATH_SEP);
                                char rawPath[1400];
                                snprintf(rawPath, sizeof(rawPath), "%s%c%s", needDir, PATH_SEP, leaf ? leaf + 1 : filename);
                                make_unique_path(rawPath, sizeof(rawPath));

                                if (device_id != DEVICE_NONE) {
                                    uint64_t written = 0;
                                    extract_ok = handle_device_carve(fd, file_start, file_size, rawPath, device_id, &written);
                                    final_size = written;
                                } else {
                                    extract_ok = ExtractFileRange(fd, file_start, file_size, rawPath);
                                }
                                snprintf(outPath, sizeof(outPath), "%s", rawPath);
                            }
                        } else {
                            // Có moov (hoặc không phải MP4) → copy nguyên khối, giữ container.
                            extract_ok = ExtractFileRange(fd, file_start, file_size, outPath);
                        }

                        if (extract_ok == 0) {
                            if (on_file) {
                                const char* savedName = strrchr(outPath, PATH_SEP);
                                on_file(context, sig->name, savedName ? savedName + 1 : outPath, "", final_size, sector_index);
                            }
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
                int64_t now = GetTimeMs();
                int32_t speed = 0;
                if (now > last_progress_ms + 10) { // ít nhất 10ms để tránh nhiễu
                    speed = (int32_t)((double)(pos - last_progress_pos) * 1000.0 / (double)(now - last_progress_ms) / (1024.0 * 1024.0));
                }
                double phase_pct = (double)pos / disk_size * 100.0;
                double pct = progress_start + (phase_pct * (progress_end - progress_start) / 100.0);
                on_progress(context, pct, pos, speed);
                last_progress_ms = now;
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
