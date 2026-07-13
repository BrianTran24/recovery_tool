#include <CoreFoundation/CoreFoundation.h>
#include <DiskArbitration/DiskArbitration.h>

// Unmount bằng diskutil subprocess (đơn giản hơn)
int UnmountDisk(const char* devicePath) {
    char cmd[256];
    // Dùng "unmount" chứ không phải "eject" — vẫn giữ /dev/disk2
    snprintf(cmd, sizeof(cmd), "diskutil unmountDisk %s", devicePath);
    int ret = system(cmd);
    return (ret == 0) ? 0 : -1;
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/disk.h>   // DKIOCGETBLOCKSIZE, DKIOCGETBLOCKCOUNT
#include <sys/stat.h>

typedef struct {
    long long totalSectors;
    uint32_t  bytesPerSector;
    long long totalBytes;
} DiskGeometry;

int OpenDisk(const char* devicePath) {
    // O_RDONLY — chỉ đọc
    // O_SYNC   — bypass page cache, đọc trực tiếp từ thiết bị
    int fd = open(devicePath, O_RDONLY | O_SYNC);
    if (fd < 0) {
        fprintf(stderr, "Không mở được %s: %s\n",
                devicePath, strerror(errno));
        if (errno == EACCES || errno == EPERM) {
            fprintf(stderr, "→ Thử chạy lại với sudo\n");
        }
        if (errno == EBUSY) {
            fprintf(stderr, "→ Volume chưa unmount, chạy: diskutil unmountDisk %s\n",
                    devicePath);
        }
    }
    return fd; // -1 nếu lỗi
}

int GetDiskGeometry(int fd, DiskGeometry* out) {
    uint32_t blockSize  = 0;
    uint64_t blockCount = 0;

    // Thử lấy geometry qua ioctl (chỉ chạy với block device)
    if (ioctl(fd, DKIOCGETBLOCKSIZE, &blockSize) == 0 &&
        ioctl(fd, DKIOCGETBLOCKCOUNT, &blockCount) == 0) {

        out->bytesPerSector = blockSize;
        out->totalSectors   = (long long)blockCount;
        out->totalBytes     = (long long)blockCount * blockSize;
    } else {
        // Fallback: Nếu là file image thông thường (không phải device)
        struct stat st;
        if (fstat(fd, &st) < 0) {
            perror("fstat failed");
            return -1;
        }

        // Mặc định sector size là 512 cho file image
        out->bytesPerSector = 512;
        out->totalBytes     = st.st_size;
        out->totalSectors   = st.st_size / 512;

        printf("Detecting regular file image. Size: %lld bytes\n", out->totalBytes);
    }

    printf("Sector size  : %u bytes\n",      out->bytesPerSector);
    printf("Total sectors: %lld\n",           out->totalSectors);
    printf("Total size   : %lld MB\n",        out->totalBytes / 1024 / 1024);
    return 0;
}

// Seek + read — đơn giản hơn Windows nhiều
int ReadSectors(int fd, long long sectorIndex, uint32_t numSectors,
                uint32_t sectorSize, uint8_t* buffer, size_t* bytesRead) {

    // Tính byte offset
    off_t offset = (off_t)sectorIndex * sectorSize;

    // Seek đến vị trí
    if (lseek(fd, offset, SEEK_SET) < 0) {
        fprintf(stderr, "lseek thất bại tại sector %lld: %s\n",
                sectorIndex, strerror(errno));
        return -1;
    }

    // Đọc
    size_t readSize = (size_t)numSectors * sectorSize;
    ssize_t n = read(fd, buffer, readSize);

    if (n < 0) {
        fprintf(stderr, "read thất bại: %s\n", strerror(errno));
        return -1;
    }

    *bytesRead = (size_t)n;
    return 0;
}