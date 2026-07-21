#include "partition_detector.h"
#include "platform_config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef _WIN32
#include <unistd.h>
#endif

#define MAX_SAMPLES 1000
#define SAMPLE_CHUNK_SIZE (1024 * 1024) // 1MB

static const uint8_t JPEG_SIG[] = {0xFF, 0xD8, 0xFF};
static const uint8_t MP4_SIG[] = {0x66, 0x74, 0x79, 0x70}; // "ftyp"

static int LooksLikeVbr(const uint8_t* sector) {
    if (sector[510] != 0x55 || sector[511] != 0xAA) return 0;
    if (memcmp(sector + 3, "EXFAT   ", 8) == 0) return 1;
    if (memcmp(sector + 3, "NTFS    ", 8) == 0) return 1;
    if (sector[0] == 0xEB || sector[0] == 0xE9) {
        if (memcmp(sector + 82, "FAT32   ", 8) == 0) return 1;
        if (sector[0] == 0xEB && sector[1] == 0x58 && sector[2] == 0x90) return 1;
    }
    return 0;
}

static uint32_t GetClusterSize(const uint8_t* vbr) {
    if (memcmp(vbr + 3, "EXFAT   ", 8) == 0) {
        return 1U << vbr[109]; // Sectors per cluster is 2^N
    }
    // FAT32
    return vbr[13];
}

static void AddCandidate(PartitionCandidate* candidates, int* count, int max_candidates, int64_t lba, uint32_t cluster_size) {
    if (*count >= max_candidates) return;
    for (int i = 0; i < *count; i++) {
        if (candidates[i].start_sector == lba) return;
    }
    candidates[*count].start_sector = lba;
    candidates[*count].cluster_size = cluster_size;
    (*count)++;
}

int DetectPartitions(int fd, int64_t disk_sectors, PartitionCandidate* candidates, int max_candidates) {
    int count = 0;
    uint8_t sector[512];

    // 1. Scan common offsets
    int64_t common_offsets[] = {0, 63, 2048, 4096, 8192, 32768, 65536};
    for (size_t i = 0; i < sizeof(common_offsets) / sizeof(common_offsets[0]); i++) {
        int64_t lba = common_offsets[i];
        if (lba >= disk_sectors) continue;

        if (PREAD(fd, sector, 512, lba * 512) == 512) {
            if (LooksLikeVbr(sector)) {
                AddCandidate(candidates, &count, max_candidates, lba, GetClusterSize(sector));
            } else {
                // Try backups
                uint8_t backup[512];
                if (PREAD(fd, backup, 512, (lba + 6) * 512) == 512 && LooksLikeVbr(backup)) {
                    AddCandidate(candidates, &count, max_candidates, lba, GetClusterSize(backup));
                } else if (PREAD(fd, backup, 512, (lba + 12) * 512) == 512 && LooksLikeVbr(backup)) {
                    AddCandidate(candidates, &count, max_candidates, lba, GetClusterSize(backup));
                }
            }
        }
    }

    // 2. Sampling Signature Scan to infer alignment if no partition found
    // If we already found a partition, we skip this time-consuming scan.
    if (count == 0) {
        int64_t sample_offsets[MAX_SAMPLES];
        int sample_count = 0;
        uint8_t* chunk = malloc(SAMPLE_CHUNK_SIZE);
        if (!chunk) return 0;

        // Scan first 1GB or disk size
        int64_t disk_size_bytes = disk_sectors * 512;
        int64_t scan_limit = (disk_size_bytes < 1024 * 1024 * 1024) ? disk_size_bytes : 1024 * 1024 * 1024;

        for (int64_t pos = 0; pos < scan_limit; pos += SAMPLE_CHUNK_SIZE) {
            ssize_t n = PREAD(fd, chunk, SAMPLE_CHUNK_SIZE, pos);
            if (n <= 0) break;

            // Note: In a real scenario, we might want to call a progress callback here too

            for (ssize_t i = 0; i < n - 16; i++) {
                if (chunk[i] == 0xFF && chunk[i+1] == 0xD8 && chunk[i+2] == 0xFF) {
                    if (sample_count < MAX_SAMPLES) {
                        sample_offsets[sample_count++] = pos + i;
                    }
                }
            }
        }
        // ... (rest of sampling logic)

        if (sample_count > 5) {
            // Infer cluster size and partition start
            uint32_t possible_clusters[] = {8, 16, 32, 64, 128, 256, 512}; // in sectors
            uint32_t best_cluster = 0;
            int64_t best_start = -1;
            int max_votes = 0;

            for (size_t ci = 0; ci < sizeof(possible_clusters)/sizeof(possible_clusters[0]); ci++) {
                uint32_t c_size_bytes = possible_clusters[ci] * 512;
                // Use a simple histogram to find the most likely remainder
                for (int s = 0; s < sample_count; s++) {
                    int64_t remainder = sample_offsets[s] % c_size_bytes;
                    int votes = 0;
                    for (int o = 0; o < sample_count; o++) {
                        if (sample_offsets[o] % c_size_bytes == remainder) votes++;
                    }
                    if (votes > max_votes) {
                        max_votes = votes;
                        best_cluster = possible_clusters[ci];
                        // This remainder is basically the offset from the partition start to the first cluster heap.
                        // We can't easily find the EXACT partition start without VBR,
                        // but we can guess it's one of the common offsets that matches this remainder.
                    }
                }
            }

            if (max_votes > sample_count / 2) {
                // High confidence in alignment.
                // Try to find VBR by checking backwards from sample_offsets[0] with best_cluster alignment
                // For simplicity, let's just mark it as a "Guessed" partition if we find any VBR.
                // Or just return the most likely common offset.
                for (size_t i = 0; i < sizeof(common_offsets) / sizeof(common_offsets[0]); i++) {
                    int64_t lba = common_offsets[i];
                    uint32_t c_size_bytes = best_cluster * 512;
                    // Check if sample_offsets are aligned with this LBA
                    if (sample_offsets[0] > lba * 512 && (sample_offsets[0] - lba * 512) % c_size_bytes == 0) {
                        // This common offset is consistent with our detected alignment!
                        candidates[0].start_sector = lba;
                        candidates[0].cluster_size = best_cluster;
                        count = 1;
                        // If we found 2048, that's usually better than 0 if both match
                        if (lba == 2048) break;
                    }
                }
            }
        }
        free(chunk);
    }

    return count;
}
