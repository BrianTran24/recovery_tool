#include "../src/partition_detector.h"
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>

void create_mock_disk(const char* path, int64_t size_mb) {
    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0666);
    ftruncate(fd, size_mb * 1024 * 1024);

    // Add a mock exFAT VBR at sector 2048
    uint8_t vbr[512] = {0};
    memcpy(vbr + 3, "EXFAT   ", 8);
    vbr[109] = 7; // 2^7 = 128 sectors per cluster
    vbr[510] = 0x55;
    vbr[511] = 0xAA;

    pwrite(fd, vbr, 512, 2048 * 512);

    // Add some "files" with signatures to test alignment inference
    uint8_t jpeg[] = {0xFF, 0xD8, 0xFF, 0xE0};
    // Alignment: Cluster size is 128 sectors = 64KB
    // First cluster starts at some offset after VBR. Let's say 2048 + 32768.
    int64_t data_start = (2048 + 32) * 512; // Much closer to start
    printf("DEBUG: Writing JPEG signatures starting at %lld\n", data_start);
    for (int i = 0; i < 20; i++) {
        pwrite(fd, jpeg, 4, data_start + i * 64 * 1024);
    }

    // WIPE VBR at 2048 to test inference
    uint8_t zero[512] = {0};
    pwrite(fd, zero, 512, 2048 * 512);

    close(fd);
}

int main() {
    const char* disk_path = "test_disk.img";
    create_mock_disk(disk_path, 10);

    int fd = open(disk_path, O_RDONLY);
    PartitionCandidate candidates[16];
    int count = DetectPartitions(fd, 10 * 1024 * 2, candidates, 16);

    printf("Found %d partition candidates\n", count);
    for (int i = 0; i < count; i++) {
        printf("Candidate %d: start=%lld, cluster_size=%u\n", i, candidates[i].start_sector, candidates[i].cluster_size);
    }

    assert(count > 0);
    assert(candidates[0].start_sector == 2048);

    close(fd);
    unlink(disk_path);
    printf("Test passed!\n");
    return 0;
}
