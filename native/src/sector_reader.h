#pragma once
#include <stdint.h>
#include <stddef.h>

typedef struct {
    long long totalSectors;
    uint32_t  bytesPerSector;
    long long totalBytes;
} DiskGeometry;

int OpenDisk(const char* devicePath);
int GetDiskGeometry(int fd, DiskGeometry* out);
int ReadSectors(int fd, long long sectorIndex, uint32_t numSectors,
                uint32_t sectorSize, uint8_t* buffer, size_t* bytesRead);
int UnmountDisk(const char* devicePath);
