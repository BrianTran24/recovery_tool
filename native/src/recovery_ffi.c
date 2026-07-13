#include "recovery_ffi.h"
#include "sector_reader.h"
#include "carver.h"
#include "fat32_parser.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>

typedef struct {
    int      fd;
    volatile int cancelled;
    int64_t  start_ms;
    RecoveryCallback cb;
    int32_t  fat_count;
    int32_t  carve_count;
} ScanSession;

static ScanSession g_sessions[8] = {0};

static int64_t NowMs(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000LL + ts.tv_nsec / 1000000;
}

// Cấp phát sự kiện trên Heap để Dart có thể đọc bất đồng bộ an toàn
static void PostEvent(ScanSession* s, const RecoveryEvent* ev) {
    if (!s->cb) return;
    RecoveryEvent* heapEv = (RecoveryEvent*)malloc(sizeof(RecoveryEvent));
    if (heapEv) {
        memcpy(heapEv, ev, sizeof(RecoveryEvent));
        s->cb(heapEv);
    }
}

static void EmitProgress(ScanSession* s, double pct, int64_t scanned, int32_t speed) {
    RecoveryEvent ev = {0};
    ev.event_type    = EVENT_PROGRESS;
    ev.percent       = pct;
    ev.scanned_bytes = scanned;
    ev.speed_mbps    = speed;
    PostEvent(s, &ev);
}

static void EmitFileFound(ScanSession* s, const char* type, const char* name, int64_t size, int64_t sector) {
    RecoveryEvent ev = {0};
    ev.event_type  = EVENT_FILE_FOUND;
    strncpy(ev.file_type, type, 15);
    strncpy(ev.filename,  name, 255);
    ev.file_size     = size;
    ev.sector_offset = sector;
    PostEvent(s, &ev);
}

static void on_carve_progress(void* ctx, double pct, int64_t scanned, int32_t speed) {
    EmitProgress((ScanSession*)ctx, pct, scanned, speed);
}

static void on_carve_file(void* ctx, const char* type, const char* name, int64_t size, int64_t sector) {
    ScanSession* s = (ScanSession*)ctx;
    EmitFileFound(s, type, name, size, sector);
    s->carve_count++;
}

static void on_fat_file(void* ctx, const char* type, const char* name, int64_t size, int64_t sector) {
    ScanSession* s = (ScanSession*)ctx;
    EmitFileFound(s, type, name, size, sector);
    s->fat_count++;
}

EXPORT int32_t recovery_unmount(const char* device_path) {
    return UnmountDisk(device_path);
}

EXPORT int32_t recovery_open(const char* device_path) {
    for (int i = 0; i < 8; i++) {
        if (g_sessions[i].fd == 0) {
            int fd = OpenDisk(device_path);
            if (fd < 0) return -errno;
            g_sessions[i].fd = fd;
            g_sessions[i].cancelled = 0;
            return i;
        }
    }
    return -100;
}

EXPORT int64_t recovery_disk_size(int32_t handle) {
    if (handle < 0 || handle >= 8) return -1;
    DiskGeometry geo;
    if (GetDiskGeometry(g_sessions[handle].fd, &geo) < 0) return -1;
    return geo.totalBytes;
}

EXPORT int32_t recovery_scan(int32_t handle, const char* output_dir, RecoveryCallback callback, int32_t enable_fat, int32_t enable_carve) {
    if (handle < 0 || handle >= 8) return -1;
    ScanSession* s = &g_sessions[handle];
    s->cb         = callback;
    s->cancelled  = 0;
    s->start_ms   = NowMs();
    s->fat_count  = 0;
    s->carve_count = 0;

    DiskGeometry geo;
    if (GetDiskGeometry(s->fd, &geo) < 0) {
        RecoveryEvent err = {0};
        err.event_type = EVENT_ERROR;
        err.error_code = -1;
        strncpy(err.error_msg, "Không thể lấy thông tin ổ đĩa", 255);
        PostEvent(s, &err);
        return -1;
    }

    // 1. Quét FAT (Quick Scan)
    if (enable_fat && !s->cancelled) {
        uint8_t sector[512];
        int found_fat = 0;

        // Thử Sector 0 trước
        if (lseek(s->fd, 0, SEEK_SET) == 0 && read(s->fd, sector, 512) == 512) {
            printf("DEBUG: Checking Sector 0...\n");

            // 1.1 Kiểm tra GPT (Signature "EFI PART" ở sector 1)
            uint8_t sector1[512];
            if (lseek(s->fd, 512, SEEK_SET) == 0 && read(s->fd, sector1, 512) == 512) {
                if (memcmp(sector1, "EFI PART", 8) == 0) {
                    printf("DEBUG: Found GPT Partition Table at Sector 1\n");
                    uint32_t entry_size = *((uint32_t*)&sector1[84]);
                    uint64_t table_lba = *((uint64_t*)&sector1[72]);
                    uint32_t num_entries = *((uint32_t*)&sector1[80]);

                    printf("DEBUG: GPT Entry size: %u, Table LBA: %llu, Num entries: %u\n", entry_size, table_lba, num_entries);

                    // Đọc nhiều entry hơn để chắc chắn (thường là 128 entry)
                    size_t read_count = (num_entries > 128) ? 128 : num_entries;
                    uint8_t* table = (uint8_t*)malloc(entry_size * read_count);
                    if (lseek(s->fd, (off_t)table_lba * 512, SEEK_SET) == 0 && read(s->fd, table, entry_size * read_count) == (ssize_t)(entry_size * read_count)) {
                        for (size_t i = 0; i < read_count; i++) {
                            uint8_t* entry = table + (i * entry_size);
                            // Partition Type GUID: Microsoft Basic Data (EBD0A0A2-B9E5-4433-87C0-68B6B72699C7)
                            static const uint8_t BASIC_DATA_GUID[16] = {0xA2, 0xA0, 0xD0, 0xEB, 0xE5, 0xB9, 0x33, 0x44, 0x87, 0xC0, 0x68, 0xB6, 0xB7, 0x26, 0x99, 0xC7};
                            if (memcmp(entry, BASIC_DATA_GUID, 16) == 0) {
                                uint64_t start_lba = *((uint64_t*)&entry[32]);
                                uint64_t end_lba = *((uint64_t*)&entry[40]);
                                printf("DEBUG: Found Potential Data Partition %zu in GPT: LBA %llu to %llu\n", i, start_lba, end_lba);

                                uint8_t vbr[512];
                                if (lseek(s->fd, (off_t)start_lba * 512, SEEK_SET) >= 0 && read(s->fd, vbr, 512) == 512) {
                                    if (RecoverAllDeletedFiles(s->fd, vbr, output_dir, s, on_fat_file, &s->cancelled) > 0) {
                                        found_fat = 1;
                                    }
                                    // Thử cả backup VBR của phân vùng này (thường ở +6)
                                    if (!found_fat && !s->cancelled) {
                                        if (lseek(s->fd, (off_t)(start_lba + 6) * 512, SEEK_SET) >= 0 && read(s->fd, vbr, 512) == 512) {
                                            if (RecoverAllDeletedFiles(s->fd, vbr, output_dir, s, on_fat_file, &s->cancelled) > 0) {
                                                found_fat = 1;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        printf("DEBUG: Failed to read GPT partition table at LBA %llu\n", table_lba);
                    }
                    free(table);
                } else {
                    printf("DEBUG: Sector 1 is not GPT (Signature: %02X %02X %02X %02X)\n",
                           sector1[0], sector1[1], sector1[2], sector1[3]);
                }
            }

            // 1.2 Kiểm tra MBR (nếu không phải GPT hoặc GPT fail)
            if (!found_fat && sector[510] == 0x55 && sector[511] == 0xAA) {
                for (int i = 0; i < 4; i++) {
                    uint8_t* entry = &sector[446 + (i * 16)];
                    uint8_t type = entry[4];
                    printf("DEBUG: MBR Partition %d type: 0x%02X\n", i, type);
                    if (type == 0x0B || type == 0x0C) {
                        uint32_t start_lba = *((uint32_t*)&entry[8]);
                        printf("DEBUG: Found FAT32 LBA %u in MBR\n", start_lba);
                        uint8_t vbr[512];
                        if (lseek(s->fd, (off_t)start_lba * 512, SEEK_SET) >= 0 && read(s->fd, vbr, 512) == 512) {
                            if (RecoverAllDeletedFiles(s->fd, vbr, output_dir, s, on_fat_file, &s->cancelled) > 0) {
                                found_fat = 1;
                            }
                            if (!found_fat && !s->cancelled) {
                                if (lseek(s->fd, (off_t)(start_lba + 6) * 512, SEEK_SET) >= 0 && read(s->fd, vbr, 512) == 512) {
                                    if (RecoverAllDeletedFiles(s->fd, vbr, output_dir, s, on_fat_file, &s->cancelled) > 0) {
                                        found_fat = 1;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 1.3 Thử coi sector 0 chính là VBR
            if (!found_fat && !s->cancelled) {
                printf("DEBUG: Trying Sector 0 as VBR...\n");
                if (RecoverAllDeletedFiles(s->fd, sector, output_dir, s, on_fat_file, &s->cancelled) > 0) {
                    found_fat = 1;
                }
            }

            // 1.4 Thử backup VBR ở sector 6 (No MBR)
            if (!found_fat && !s->cancelled) {
                printf("DEBUG: Trying Sector 6 as VBR...\n");
                if (lseek(s->fd, 6 * 512, SEEK_SET) >= 0 && read(s->fd, sector, 512) == 512) {
                    if (RecoverAllDeletedFiles(s->fd, sector, output_dir, s, on_fat_file, &s->cancelled) > 0) {
                        found_fat = 1;
                    }
                }
            }
        }

        // 1.5 Quét diện rộng (Searching for VBR signature)
        if (!found_fat && !s->cancelled) {
            // Mở rộng phạm vi quét lên 32768 sector (khoảng 16MB đầu tiên)
            // Nhiều thiết bị hiện đại có offset phân vùng rất lớn (ví dụ 32768 cho SD card)
            printf("DEBUG: Quick scan failed, searching first 32768 sectors for VBR...\n");
            for (int i = 1; i < 32768; i++) {
                if (s->cancelled) break;

                // Cứ mỗi 4096 sector thì log progress để user không tưởng treo máy
                if (i % 4096 == 0) printf("DEBUG: Searching... at sector %d\n", i);

                if (lseek(s->fd, (off_t)i * 512, SEEK_SET) < 0) break;
                if (read(s->fd, sector, 512) != 512) break;

                // Kiểm tra signature Boot Record (0x55AA)
                if (sector[510] == 0x55 && sector[511] == 0xAA) {
                    // Thêm kiểm tra Jump Instruction (EB XX 90 hoặc E9 XX XX) để tránh false positive
                    if (sector[0] == 0xEB || sector[0] == 0xE9) {
                        if (RecoverAllDeletedFiles(s->fd, sector, output_dir, s, on_fat_file, &s->cancelled) > 0) {
                            found_fat = 1;
                            printf("DEBUG: Found valid FAT32 VBR at sector %d\n", i);
                            break;
                        }
                    }
                }
            }
        }
    }

    // 2. Quét Signature (Deep Scan)
    if (enable_carve && !s->cancelled) {
        CarveFilesWithProgress(s->fd, geo.totalBytes, geo.bytesPerSector, s, on_carve_progress, on_carve_file, &s->cancelled);
    }

    RecoveryEvent done = {0};
    done.event_type  = EVENT_DONE;
    done.total_found = s->fat_count + s->carve_count;
    done.fat_count   = s->fat_count;
    done.carve_count = s->carve_count;
    done.duration_ms = NowMs() - s->start_ms;
    PostEvent(s, &done);

    return done.total_found;
}

EXPORT void recovery_cancel(int32_t handle) {
    if (handle >= 0 && handle < 8) g_sessions[handle].cancelled = 1;
}

EXPORT void recovery_close(int32_t handle) {
    if (handle >= 0 && handle < 8 && g_sessions[handle].fd > 0) {
        close(g_sessions[handle].fd);
        memset(&g_sessions[handle], 0, sizeof(ScanSession));
    }
}

EXPORT int32_t recovery_save_file(int32_t handle, int64_t sector_offset, int64_t file_size, const char* output_path) {
    if (handle < 0 || handle >= 8) return -1;
    if (g_sessions[handle].fd <= 0) return -2;

    // sector_offset là sector, cần đổi ra bytes
    uint64_t start_byte = (uint64_t)sector_offset * 512; // Mặc định 512, có thể lấy từ geometry nếu cần

    // Thử lấy sector size thật từ ổ đĩa
    DiskGeometry geo;
    if (GetDiskGeometry(g_sessions[handle].fd, &geo) == 0) {
        start_byte = (uint64_t)sector_offset * geo.bytesPerSector;
    }

    return ExtractFileRange(g_sessions[handle].fd, start_byte, (uint64_t)file_size, output_path);
}
