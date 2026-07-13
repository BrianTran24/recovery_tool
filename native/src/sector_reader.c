#include "sector_reader.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#else
#include <CoreFoundation/CoreFoundation.h>
#include <DiskArbitration/DiskArbitration.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/disk.h>
#include <sys/stat.h>
#endif

#ifdef _WIN32
// === Windows Implementation ===

int UnmountDisk(const char* devicePath) {
    return 0;
}

int OpenDisk(const char* devicePath) {
    HANDLE hDisk = CreateFileA(
        devicePath,
        GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        NULL
    );

    if (hDisk == INVALID_HANDLE_VALUE) {
        DWORD err = GetLastError();
        fprintf(stderr, "Cannot open %s, Error: %lu\n", devicePath, err);
        return -(int)err;
    }

    // Convert HANDLE to POSIX file descriptor so lseek/read work
    int fd = _open_osfhandle((intptr_t)hDisk, _O_RDONLY | _O_BINARY);
    if (fd == -1) {
        CloseHandle(hDisk);
        return -1;
    }

    return fd;
}

int GetDiskGeometry(int fd, DiskGeometry* out) {
    HANDLE hDisk = (HANDLE)_get_osfhandle(fd);
    if (hDisk == INVALID_HANDLE_VALUE) return -1;

    DISK_GEOMETRY_EX dg;
    DWORD bytesReturned;
    if (DeviceIoControl(hDisk, IOCTL_DISK_GET_DRIVE_GEOMETRY_EX, NULL, 0, &dg, sizeof(dg), &bytesReturned, NULL)) {
        out->bytesPerSector = dg.Geometry.BytesPerSector;
        out->totalBytes = dg.DiskSize.QuadPart;
        out->totalSectors = out->totalBytes / out->bytesPerSector;
    } else {
        LARGE_INTEGER fileSize;
        if (!GetFileSizeEx(hDisk, &fileSize)) return -1;
        out->bytesPerSector = 512;
        out->totalBytes = fileSize.QuadPart;
        out->totalSectors = out->totalBytes / 512;
    }
    return 0;
}

int ReadSectors(int fd, long long sectorIndex, uint32_t numSectors,
                uint32_t sectorSize, uint8_t* buffer, size_t* bytesRead) {
    off_t offset = (off_t)sectorIndex * sectorSize;
    if (_lseeki64(fd, offset, SEEK_SET) == -1L) return -1;

    int n = _read(fd, buffer, numSectors * sectorSize);
    if (n < 0) return -1;

    *bytesRead = (size_t)n;
    return 0;
}

#else
// === macOS / POSIX Implementation ===

int UnmountDisk(const char* devicePath) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "diskutil unmountDisk %s", devicePath);
    int ret = system(cmd);
    return (ret == 0) ? 0 : -1;
}

int OpenDisk(const char* devicePath) {
    int fd = open(devicePath, O_RDONLY | O_SYNC);
    if (fd < 0) {
        fprintf(stderr, "Cannot open %s: %s\n", devicePath, strerror(errno));
    }
    return fd;
}

int GetDiskGeometry(int fd, DiskGeometry* out) {
    uint32_t blockSize  = 0;
    uint64_t blockCount = 0;

    if (ioctl(fd, DKIOCGETBLOCKSIZE, &blockSize) == 0 &&
        ioctl(fd, DKIOCGETBLOCKCOUNT, &blockCount) == 0) {
        out->bytesPerSector = blockSize;
        out->totalSectors   = (long long)blockCount;
        out->totalBytes     = (long long)blockCount * blockSize;
    } else {
        struct stat st;
        if (fstat(fd, &st) < 0) return -1;
        out->bytesPerSector = 512;
        out->totalBytes     = st.st_size;
        out->totalSectors   = st.st_size / 512;
    }
    return 0;
}

int ReadSectors(int fd, long long sectorIndex, uint32_t numSectors,
                uint32_t sectorSize, uint8_t* buffer, size_t* bytesRead) {
    off_t offset = (off_t)sectorIndex * sectorSize;
    if (lseek(fd, offset, SEEK_SET) < 0) return -1;
    ssize_t n = read(fd, buffer, (size_t)numSectors * sectorSize);
    if (n < 0) return -1;
    *bytesRead = (size_t)n;
    return 0;
}

#endif
