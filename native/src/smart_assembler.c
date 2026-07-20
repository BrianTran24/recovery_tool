#include "smart_assembler.h"
#include "platform_config.h"
#include "carver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#ifdef _WIN32
#define PATH_SEP '\\'
#else
#define PATH_SEP '/'
#endif

// Forward declarations from fat32/exfat parsers
extern int ReadCluster(int fd, const void* info, uint32_t cluster, uint8_t* buf);

static void MarkSectors(uint8_t* mask, int64_t total, int64_t start, int64_t count) {
    if (!mask) return;
    for (int64_t i = 0; i < count; i++) {
        int64_t idx = start + i;
        if (idx >= 0 && idx < total) {
            mask[idx >> 3] |= (1 << (idx & 7));
        }
    }
}

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
    if (len >= 3 && isalpha(tmp[0]) && tmp[1] == ':' && tmp[2] == PATH_SEP) p = tmp + 3;
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

static int is_path_sep(char c) {
    return c == '/' || c == '\\';
}

static void sanitize_path_component(const char* src, char* dst, size_t dstSize) {
    size_t written = 0;

    if (!dst || dstSize == 0) return;
    dst[0] = '\0';
    if (!src) return;

    while (*src && written + 1 < dstSize) {
        unsigned char ch = (unsigned char)*src++;
        if (ch < 32 || ch == '<' || ch == '>' || ch == ':' || ch == '"' ||
            ch == '|' || ch == '?' || ch == '*' || ch == '/' || ch == '\\') {
            ch = '_';
        }
        dst[written++] = (char)ch;
    }
    dst[written] = '\0';

    while (written > 0 && (dst[written - 1] == ' ' || dst[written - 1] == '.')) {
        dst[--written] = '\0';
    }

    if (written == 0 || strcmp(dst, ".") == 0 || strcmp(dst, "..") == 0) {
        snprintf(dst, dstSize, "_");
    }
}

static void sanitize_relative_path(const char* relPath, char* out, size_t outSize) {
    size_t written = 0;

    if (!out || outSize == 0) return;
    out[0] = '\0';
    if (!relPath || !*relPath) return;

    while (*relPath) {
        while (*relPath && is_path_sep(*relPath)) relPath++;
        if (!*relPath) break;

        const char* start = relPath;
        while (*relPath && !is_path_sep(*relPath)) relPath++;

        char segment[256];
        size_t len = (size_t)(relPath - start);
        if (len >= sizeof(segment)) len = sizeof(segment) - 1;
        memcpy(segment, start, len);
        segment[len] = '\0';
        sanitize_path_component(segment, segment, sizeof(segment));
        if (segment[0] == '\0') continue;

        size_t segLen = strlen(segment);
        if (written > 0 && written + 1 < outSize) {
            out[written++] = PATH_SEP;
        }
        if (written + segLen >= outSize) segLen = outSize - written - 1;
        memcpy(out + written, segment, segLen);
        written += segLen;
        out[written] = '\0';
        if (written + 1 >= outSize) break;
    }
}

static void sanitize_filename(const char* src, char* dst, size_t dstSize, const char* fallback) {
    sanitize_path_component(src, dst, dstSize);
    if (dst[0] == '\0' && fallback) {
        snprintf(dst, dstSize, "%s", fallback);
    }
}

static int file_exists(const char* path) {
    FILE* f = fopen(path, "rb");
    if (!f) return 0;
    fclose(f);
    return 1;
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
            if (ext[0]) {
                snprintf(candidate, sizeof(candidate), "%s%c%s_%u%s", dir, PATH_SEP, stem, i, ext);
            } else {
                snprintf(candidate, sizeof(candidate), "%s%c%s_%u", dir, PATH_SEP, stem, i);
            }
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

static int AssembleHealthy(int fd, FileInfo* info, const char* outPath, uint32_t bytesPerCluster, uint32_t sectorsPerCluster, int64_t dataStartSector, uint8_t* mask, int64_t totalSectors) {
    FILE* out = fopen(outPath, "wb");
    if (!out) return -1;

    uint8_t* buf = (uint8_t*)malloc(bytesPerCluster);
    int64_t remaining = info->file_size;
    int success = 0;

    for (uint32_t i = 0; i < info->chain_length && remaining > 0; i++) {
        uint32_t cluster = info->cluster_chain[i];
        int64_t sector = dataStartSector + (int64_t)(cluster - 2) * sectorsPerCluster;

        if (LSEEK(fd, sector * 512, SEEK_SET) < 0) break;
        if (READ(fd, buf, bytesPerCluster) != (ssize_t)bytesPerCluster) break;

        uint32_t writeSize = (remaining < bytesPerCluster) ? (uint32_t)remaining : bytesPerCluster;
        fwrite(buf, 1, writeSize, out);
        remaining -= writeSize;
        MarkSectors(mask, totalSectors, sector, sectorsPerCluster);
    }

    if (remaining == 0) success = 1;
    fclose(out);
    free(buf);
    return success ? 0 : -1;
}

static int AssembleSmart(int fd, FileInfo* info, const char* outPath, uint32_t bytesPerCluster, uint32_t sectorsPerCluster, int64_t dataStartSector, uint8_t* mask, int64_t totalSectors, volatile int* cancelled) {
    FILE* out = fopen(outPath, "wb");
    if (!out) return -1;

    uint8_t* buf = (uint8_t*)malloc(bytesPerCluster);
    int64_t remaining = info->file_size;
    uint32_t curr = info->starting_cluster;
    int success = 0;
    int fragmented_jumps = 0;

    while (remaining > 0 && curr >= 2 && (!cancelled || !*cancelled)) {
        int64_t sector = dataStartSector + (int64_t)(curr - 2) * sectorsPerCluster;
        if (LSEEK(fd, sector * 512, SEEK_SET) < 0) break;
        if (READ(fd, buf, bytesPerCluster) != (ssize_t)bytesPerCluster) break;

        // CẢI TIẾN: Fragmentation Detection & Avoidance
        // Nếu cluster hiện tại trông giống header của một file khác (JPG, MP4, v.v.),
        // nghĩa là file hiện tại bị phân mảnh. Ta cần tìm vùng trống tiếp theo.
        if (is_cluster_header(buf, bytesPerCluster)) {
            // Found a header of another file!
            // Nếu đây là cluster đầu tiên của chính file này thì không sao.
            if (curr != info->starting_cluster) {
                if (fragmented_jumps++ < 512) { // Giới hạn số lần nhảy để tránh lặp vô hạn
                    uint32_t search_start = curr + 1;
                    int found_gap = 0;
                    // Tìm kiếm tới 1024 cluster tiếp theo để tìm vùng không phải header
                    for (uint32_t j = 0; j < 1024; j++) {
                        uint32_t next_c = search_start + j;
                        int64_t next_s = dataStartSector + (int64_t)(next_c - 2) * sectorsPerCluster;

                        // Nếu sector đã dùng bởi FS khác, skip
                        if (mask && (mask[next_s >> 3] & (1 << (next_s & 7)))) continue;

                        uint8_t probe[512];
                        LSEEK(fd, next_s * 512, SEEK_SET);
                        if (READ(fd, probe, 512) == 512) {
                            if (!is_cluster_header(probe, 512)) {
                                curr = next_c;
                                found_gap = 1;
                                break;
                            }
                        }
                    }
                    if (found_gap) continue; // Thử lại với cluster mới tìm được
                }
            }
        }

        uint32_t writeSize = (remaining < bytesPerCluster) ? (uint32_t)remaining : bytesPerCluster;
        fwrite(buf, 1, writeSize, out);
        remaining -= writeSize;
        MarkSectors(mask, totalSectors, sector, sectorsPerCluster);
        curr++;
    }

    if (remaining == 0) success = 1;
    fclose(out);
    free(buf);
    return success ? 0 : -1;
}

int ProcessFiles(int fd, int64_t baseSector, FileCollector* collector, const char* outputDir, void* context, FatFileCallback on_file, FatProgressCallback on_progress, volatile int* cancelled, uint8_t* sector_mask, int64_t total_sectors) {
    // We need some info from BPB again, or we could pass it.
    // For simplicity, let's assume standard FAT32/exFAT detection here or pass a struct.
    // I'll re-read the boot sector to get cluster info.
    uint8_t boot[512];
    LSEEK(fd, baseSector * 512, SEEK_SET);
    READ(fd, boot, 512);

    uint32_t bpc = 0, spc = 0;
    int64_t dataStart = 0;

    if (memcmp(boot + 3, "EXFAT   ", 8) == 0) {
        uint32_t clusterHeapOffset = *(uint32_t*)(boot + 88);
        bpc = 1 << (boot[108] + boot[109]);
        spc = 1 << boot[109];
        dataStart = baseSector + clusterHeapOffset;
    } else {
        uint16_t resSectors = *(uint16_t*)(boot + 14);
        uint8_t numFats = boot[16];
        uint32_t fatSize = *(uint32_t*)(boot + 36);
        spc = boot[13];
        bpc = spc * 512;
        dataStart = baseSector + resSectors + (numFats * fatSize);
    }

    int recovered = 0;
    for (uint32_t i = 0; i < collector->count; i++) {
        if (cancelled && *cancelled) break;
        FileInfo* fi = &collector->files[i];

        char outDir[1024];
        if (fi->status == FILE_STATUS_ORPHANED) {
            snprintf(outDir, sizeof(outDir), "%s%cORPHANED", outputDir, PATH_SEP);
        } else if (fi->is_deleted) {
            snprintf(outDir, sizeof(outDir), "%s%cDELETED", outputDir, PATH_SEP);
        } else if (fi->rel_path[0]) {
            char safeRel[512];
            sanitize_relative_path(fi->rel_path, safeRel, sizeof(safeRel));
            if (safeRel[0]) snprintf(outDir, sizeof(outDir), "%s%c%s", outputDir, PATH_SEP, safeRel);
            else snprintf(outDir, sizeof(outDir), "%s", outputDir);
        } else {
            snprintf(outDir, sizeof(outDir), "%s", outputDir);
        }
        mkdir_p(outDir);

        char outPath[2048];
        char safeName[256];
        char fallback[32];
        snprintf(fallback, sizeof(fallback), "FILE_%u", fi->starting_cluster);
        sanitize_filename(fi->filename, safeName, sizeof(safeName), fallback);
        snprintf(outPath, sizeof(outPath), "%s%c%s", outDir, PATH_SEP, safeName);
        make_unique_path(outPath, sizeof(outPath));

        int res = -1;
        if (fi->status == FILE_STATUS_HEALTHY && fi->chain_length > 0) {
            res = AssembleHealthy(fd, fi, outPath, bpc, spc, dataStart, sector_mask, total_sectors);
        } else {
            res = AssembleSmart(fd, fi, outPath, bpc, spc, dataStart, sector_mask, total_sectors, cancelled);
        }

        if (res == 0) {
            recovered++;
            if (on_file) {
                int64_t sector_offset = dataStart + (int64_t)(fi->starting_cluster - 2) * spc;
                const char* savedName = strrchr(outPath, PATH_SEP);
                on_file(context, (fi->status == FILE_STATUS_ORPHANED ? "ORPHAN" : "FAT"), savedName ? savedName + 1 : outPath, fi->modified_time, fi->file_size, sector_offset, (fi->file_size + bpc - 1) / bpc * spc, fi->rel_path);
            }
        }

        if (on_progress) {
            on_progress(context, (double)(i + 1) / collector->count * 100.0, i, 0);
        }
    }

    return recovered;
}
