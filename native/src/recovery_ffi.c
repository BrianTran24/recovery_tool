#include "recovery_ffi.h"
#include "sector_reader.h"
#include "carver.h"
#include "fat32_parser.h"
#include "platform_config.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdio.h>

typedef struct {
    int      fd;
    volatile int cancelled;
    int64_t  start_ms;
    RecoveryCallback cb;
    int32_t  fat_count;
    int32_t  carve_count;
    double   progress_base;
    double   progress_span;
} ScanSession;

static ScanSession g_sessions[8] = {0};

static int64_t NowMs(void) {
#ifdef _WIN32
    return GetTickCount64();
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000LL + ts.tv_nsec / 1000000;
#endif
}

static void PostEvent(ScanSession* s, const RecoveryEvent* ev) {
    if (!s->cb) return;
    s->cb(ev);
}

static void EmitProgress(ScanSession* s, double pct, int64_t scanned, int32_t speed) {
    RecoveryEvent ev = {0};
    ev.event_type    = EVENT_PROGRESS;
    ev.percent       = pct;
    ev.scanned_bytes = scanned;
    ev.speed_mbps    = speed;
    PostEvent(s, &ev);
}

static void EmitPhaseProgress(ScanSession* s, double pct, int64_t scanned, int32_t speed) {
    double mapped = s->progress_base + (pct * s->progress_span / 100.0);
    if (mapped < 0.0) mapped = 0.0;
    if (mapped > 100.0) mapped = 100.0;
    EmitProgress(s, mapped, scanned, speed);
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

static void on_fat_progress(void* ctx, double pct, int64_t scanned, int32_t speed) {
    EmitPhaseProgress((ScanSession*)ctx, pct, scanned, speed);
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
        if (g_sessions[i].fd <= 0) {
            int fd = OpenDisk(device_path);
            if (fd < 0) return fd; // Return the error code directly
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
    s->progress_base = 0.0;
    s->progress_span = enable_carve ? 40.0 : 100.0;

    DiskGeometry geo;
    if (GetDiskGeometry(s->fd, &geo) < 0) {
        RecoveryEvent err = {0};
        err.event_type = EVENT_ERROR;
        err.error_code = -1;
        strncpy(err.error_msg, "Không thể lấy thông tin ổ đĩa", 255);
        PostEvent(s, &err);
        return -1;
    }

    if (enable_fat && !s->cancelled) {
        uint8_t sector[512];
        int found_fat = 0;

        EmitPhaseProgress(s, 0.5, 0, 0);

        if (LSEEK(s->fd, 0, SEEK_SET) == 0 && READ(s->fd, sector, 512) == 512) {
            uint8_t sector1[512];
            if (LSEEK(s->fd, 512, SEEK_SET) == 512 && READ(s->fd, sector1, 512) == 512) {
                if (memcmp(sector1, "EFI PART", 8) == 0) {
                    uint32_t entry_size = *((uint32_t*)&sector1[84]);
                    uint64_t table_lba = *((uint64_t*)&sector1[72]);
                    uint32_t num_entries = *((uint32_t*)&sector1[80]);

                    size_t read_count = (num_entries > 128) ? 128 : num_entries;
                    uint8_t* table = (uint8_t*)malloc(entry_size * read_count);
                    if (LSEEK(s->fd, (int64_t)table_lba * 512, SEEK_SET) >= 0 && READ(s->fd, table, (uint32_t)(entry_size * read_count)) == (ssize_t)(entry_size * read_count)) {
                        for (size_t i = 0; i < read_count; i++) {
                            if ((i & 15U) == 0U) {
                                double pct = 1.0 + ((double)i / (double)(read_count == 0 ? 1 : read_count)) * 8.0;
                                EmitPhaseProgress(s, pct, (int64_t)(table_lba + i) * 512, 0);
                            }
                            uint8_t* entry = table + (i * entry_size);
                            static const uint8_t BASIC_DATA_GUID[16] = {0xA2, 0xA0, 0xD0, 0xEB, 0xE5, 0xB9, 0x33, 0x44, 0x87, 0xC0, 0x68, 0xB6, 0xB7, 0x26, 0x99, 0xC7};
                            if (memcmp(entry, BASIC_DATA_GUID, 16) == 0) {
                                uint64_t start_lba = *((uint64_t*)&entry[32]);
                                uint8_t vbr[512];
                                if (LSEEK(s->fd, (int64_t)start_lba * 512, SEEK_SET) >= 0 && READ(s->fd, vbr, 512) == 512) {
                                    if (RecoverAllDeletedFiles(s->fd, vbr, output_dir, s, on_fat_file, on_fat_progress, &s->cancelled) > 0) {
                                        found_fat = 1;
                                    }
                                }
                            }
                        }
                    }
                    free(table);
                }
            }

            if (!found_fat && sector[510] == 0x55 && sector[511] == 0xAA) {
                for (int i = 0; i < 4; i++) {
                    uint8_t* entry = &sector[446 + (i * 16)];
                    uint8_t type = entry[4];
                    if (type == 0x0B || type == 0x0C) {
                        uint32_t start_lba = *((uint32_t*)&entry[8]);
                        uint8_t vbr[512];
                        if (LSEEK(s->fd, (int64_t)start_lba * 512, SEEK_SET) >= 0 && READ(s->fd, vbr, 512) == 512) {
                            if (RecoverAllDeletedFiles(s->fd, vbr, output_dir, s, on_fat_file, on_fat_progress, &s->cancelled) > 0) {
                                found_fat = 1;
                            }
                        }
                    }
                }
            }

            if (!found_fat && !s->cancelled) {
                if (RecoverAllDeletedFiles(s->fd, sector, output_dir, s, on_fat_file, on_fat_progress, &s->cancelled) > 0) {
                    found_fat = 1;
                }
            }
        }

        if (!found_fat && !s->cancelled) {
            for (int i = 1; i < 32768; i++) {
                if (s->cancelled) break;
                if (LSEEK(s->fd, (int64_t)i * 512, SEEK_SET) < 0) break;
                if (READ(s->fd, sector, 512) != 512) break;

                if ((i & 255) == 0) {
                    double pct = 12.0 + ((double)i / 32767.0) * 28.0;
                    EmitPhaseProgress(s, pct, (int64_t)i * 512, 0);
                }

                if (sector[510] == 0x55 && sector[511] == 0xAA) {
                    if (sector[0] == 0xEB || sector[0] == 0xE9) {
                        if (RecoverAllDeletedFiles(s->fd, sector, output_dir, s, on_fat_file, on_fat_progress, &s->cancelled) > 0) {
                            found_fat = 1;
                            break;
                        }
                    }
                }
            }
        }

        EmitPhaseProgress(s, enable_carve ? 40.0 : 100.0, 0, 0);
    }

    if (enable_carve && !s->cancelled) {
        double carve_start = enable_fat ? 40.0 : 0.0;
        CarveFilesWithProgress(s->fd, geo.totalBytes, geo.bytesPerSector, output_dir, s, on_carve_progress, on_carve_file, &s->cancelled, carve_start, 100.0);
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
        CLOSE(g_sessions[handle].fd);
        memset(&g_sessions[handle], 0, sizeof(ScanSession));
    }
}

EXPORT void recovery_free_string(char* ptr) {
    if (ptr) free(ptr);
}

EXPORT int32_t recovery_save_file(int32_t handle, int64_t sector_offset, int64_t file_size, const char* output_path) {
    if (handle < 0 || handle >= 8) return -1;
    if (g_sessions[handle].fd <= 0) return -2;
    uint64_t start_byte = (uint64_t)sector_offset * 512;
    DiskGeometry geo;
    if (GetDiskGeometry(g_sessions[handle].fd, &geo) == 0) {
        start_byte = (uint64_t)sector_offset * geo.bytesPerSector;
    }
    return ExtractFileRange(g_sessions[handle].fd, start_byte, (uint64_t)file_size, output_path);
}
