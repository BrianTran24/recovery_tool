#include "smart_assembler.h"
#include "platform_config.h"
#include "carver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    double last_entropy = -1.0;
    int success = 0;

    while (remaining > 0 && curr >= 2 && (!cancelled || !*cancelled)) {
        int64_t sector = dataStartSector + (int64_t)(curr - 2) * sectorsPerCluster;
        if (LSEEK(fd, sector * 512, SEEK_SET) < 0) break;
        if (READ(fd, buf, bytesPerCluster) != (ssize_t)bytesPerCluster) break;

        // Fragmentation Detection
        if (is_cluster_header(buf, bytesPerCluster)) {
            // Found a header of another file! Need to find next gap.
            uint32_t next_gap = curr + 1;
            int found = 0;
            // Search up to 2048 clusters ahead
            for (int j = 0; j < 2048; j++) {
                int64_t s2 = dataStartSector + (int64_t)(next_gap + j - 2) * sectorsPerCluster;
                // If sector is already used, skip
                if (mask && (mask[s2 >> 3] & (1 << (s2 & 7)))) continue;

                // Read and check if it's a header
                uint8_t tmp[512];
                LSEEK(fd, s2 * 512, SEEK_SET);
                READ(fd, tmp, 512);
                if (!is_cluster_header(tmp, 512)) {
                    curr = next_gap + j;
                    found = 1;
                    break;
                }
            }
            if (!found) break;
            continue; // Re-read the found cluster
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
        if (fi->status == FILE_STATUS_ORPHANED) snprintf(outDir, sizeof(outDir), "%s%cORPHANED", outputDir, PATH_SEP);
        else if (fi->is_deleted) snprintf(outDir, sizeof(outDir), "%s%cDELETED", outputDir, PATH_SEP);
        else snprintf(outDir, sizeof(outDir), "%s%c%s", outputDir, PATH_SEP, fi->rel_path);
        mkdir_p(outDir);

        char outPath[2048];
        snprintf(outPath, sizeof(outPath), "%s%c%s", outDir, PATH_SEP, fi->filename);

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
                on_file(context, (fi->status == FILE_STATUS_ORPHANED ? "ORPHAN" : "FAT"), fi->filename, fi->modified_time, fi->file_size, sector_offset, (fi->file_size + bpc - 1) / bpc * spc);
            }
        }

        if (on_progress) {
            on_progress(context, (double)(i + 1) / collector->count * 100.0, i, 0);
        }
    }

    return recovered;
}
