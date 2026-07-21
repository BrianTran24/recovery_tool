#include "recovery_ffi.h"
#include "sector_reader.h"
#include "carver.h"
#include "fat32_parser.h"
#include "exfat_parser.h"
#include "smart_assembler.h"
#include "partition_detector.h"
#include "video_repair.h"
#include "platform_config.h"
#include "hardware_health_checker.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdio.h>

#ifdef _WIN32
#define FFI_PATH_SEP '\\'
#else
#define FFI_PATH_SEP '/'
#endif

// Nhận diện VBR filesystem bằng NỘI DUNG (không dựa vào partition type byte của MBR).
// Trả về loại FS_TYPE_*.
static int IdentifyFsFromVbr(const uint8_t* vbr) {
    if (vbr[510] != 0x55 || vbr[511] != 0xAA) return FS_TYPE_UNKNOWN;
    if (memcmp(vbr + 3, "EXFAT   ", 8) == 0) return FS_TYPE_EXFAT;
    if (memcmp(vbr + 3, "NTFS    ", 8) == 0) return FS_TYPE_NTFS;
    if (vbr[0] == 0xEB || vbr[0] == 0xE9) {
        // Có thể là FAT32 hoặc FAT16/12. Ta kiểm tra sơ bộ chữ FAT32.
        if (memcmp(vbr + 82, "FAT32   ", 8) == 0) return FS_TYPE_FAT32;
        // Một số thẻ nhớ đời cũ hoặc format lạ có thể không có string "FAT32" ở đúng chỗ,
        // nhưng cấu trúc nhảy 0xEB 0x58 0x90 là đặc trưng FAT32.
        if (vbr[0] == 0xEB && vbr[1] == 0x58 && vbr[2] == 0x90) return FS_TYPE_FAT32;
        return FS_TYPE_FAT32; // Fallback
    }
    return FS_TYPE_UNKNOWN;
}

static int LooksLikeFsVbr(const uint8_t* vbr) {
    return IdentifyFsFromVbr(vbr) != FS_TYPE_UNKNOWN;
}

// Kiểm tra Ext4 Superblock (sector 2, offset 0x400)
static int IsExt4(int fd, int64_t baseSector) {
    uint8_t sb[1024];
    if (LSEEK(fd, (baseSector * 512) + 1024, SEEK_SET) < 0) return 0;
    if (READ(fd, sb, 1024) != 1024) return 0;
    // Magic 0xEF53 at offset 0x38 (56) within superblock
    uint16_t magic = sb[0x38] | (sb[0x39] << 8);
    return (magic == 0xEF53);
}

typedef struct {
    int      fd;
    volatile int cancelled;
    int64_t  start_ms;
    RecoveryCallback cb;
    int32_t  fat_count;
    int32_t  carve_count;
    double   progress_base;
    double   progress_span;
    uint8_t* sector_mask;
    int64_t  total_sectors;
    char     reference_video[1024];
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

static void EmitFileFound(ScanSession* s, const char* type, const char* name, const char* modifiedTime, int64_t size, int64_t sector, int32_t status, const char* folder) {
    RecoveryEvent ev = {0};
    ev.event_type  = EVENT_FILE_FOUND;
    strncpy(ev.file_type, type, 15);
    strncpy(ev.filename,  name, 255);
    if (modifiedTime) {
        strncpy(ev.modified_time, modifiedTime, 31);
    }
    if (folder) {
        strncpy(ev.folder, folder, 255);
    }
    ev.file_size     = size;
    ev.sector_offset = sector;
    ev.status        = status;
    PostEvent(s, &ev);
}

static void MarkSectorsUsed(ScanSession* s, int64_t start_sector, int64_t count) {
    if (!s->sector_mask) return;
    for (int64_t i = 0; i < count; i++) {
        int64_t idx = start_sector + i;
        if (idx >= 0 && idx < s->total_sectors) {
            s->sector_mask[idx >> 3] |= (1 << (idx & 7));
        }
    }
}

static void on_carve_progress(void* ctx, double pct, int64_t scanned, int32_t speed) {
    EmitProgress((ScanSession*)ctx, pct, scanned, speed);
}

static void on_fat_progress(void* ctx, double pct, int64_t scanned, int32_t speed) {
    EmitPhaseProgress((ScanSession*)ctx, pct, scanned, speed);
}

static void on_carve_file(void* ctx, const char* type, const char* name, const char* modifiedTime, int64_t size, int64_t sector) {
    ScanSession* s = (ScanSession*)ctx;
    EmitFileFound(s, type, name, modifiedTime, size, sector, FILE_STATUS_CARVED, "");
    s->carve_count++;
}

static void on_fat_file(void* ctx, const char* type, const char* name, const char* modifiedTime, int64_t size, int64_t sector, int64_t sector_count, const char* folder) {
    ScanSession* s = (ScanSession*)ctx;
    int32_t status = (type && strcmp(type, "ORPHAN") == 0) ? FILE_STATUS_ORPHANED : FILE_STATUS_HEALTHY;
    EmitFileFound(s, type, name, modifiedTime, size, sector, status, folder);
    s->fat_count++;
}

static int RecoverVolumeFiles(
    ScanSession* s,
    const uint8_t* sector0,
    int64_t baseSector,
    const char* output_dir,
    int enable_fat,
    int scan_mode
) {
    if (!enable_fat) return 0;

    FileCollector collector = {0};
    double orig_base = s->progress_base;
    double orig_span = s->progress_span;

    fprintf(stderr, "[DBG] RVF enter base=%lld exfat=%d\n", (long long)baseSector, memcmp(sector0+3,"EXFAT   ",8)==0); fflush(stderr);

    // Module 1: Collect Healthy Files (Duyệt cây thư mục) - Chiếm 5% pha FS
    s->progress_base = orig_base;
    s->progress_span = orig_span * 0.05;
    if (memcmp(sector0 + 3, "EXFAT   ", 8) == 0) {
        CollectHealthyFilesExfat(s->fd, baseSector, sector0, &collector, s, on_fat_progress, &s->cancelled, scan_mode);
    } else {
        CollectHealthyFilesFat32(s->fd, baseSector, sector0, &collector, s, on_fat_progress, &s->cancelled, scan_mode);
    }

    fprintf(stderr, "[DBG] after Module1 collector.count=%u\n", collector.count); fflush(stderr);

    // Module 2: Collect Orphaned Entries (Quét mù toàn ổ) - Chiếm 75% pha FS
    s->progress_base = orig_base + (orig_span * 0.05);
    s->progress_span = orig_span * 0.75;

    // Thực hiện quét tuyến tính (sweep) nếu không phải chế độ quét nhanh (Existing)
    // HOẶC nếu quét nhanh không tìm thấy gì (dấu hiệu cấu trúc FS bị hỏng nặng).
    if (!s->cancelled && (scan_mode != SCAN_MODE_EXISTING || collector.count == 0)) {
        if (memcmp(sector0 + 3, "EXFAT   ", 8) == 0) {
            ScanOrphanedEntriesExfat(s->fd, baseSector, sector0, &collector, s, on_fat_progress, &s->cancelled);
        } else {
            ScanOrphanedEntriesFat32(s->fd, baseSector, sector0, &collector, s, on_fat_progress, &s->cancelled);
        }
    }

    fprintf(stderr, "[DBG] after Module2 collector.count=%u\n", collector.count); fflush(stderr);

    // Module 3: Smart Assembler (Ghi file ra đĩa) - Chiếm 20% pha FS
    s->progress_base = orig_base + (orig_span * 0.80);
    s->progress_span = orig_span * 0.20;

    int recovered = 0;
    if (!s->cancelled && collector.count > 0) {
        recovered = ProcessFiles(s->fd, baseSector, &collector, output_dir, s, on_fat_file, on_fat_progress, &s->cancelled, s->sector_mask, s->total_sectors);
    }

    fprintf(stderr, "[DBG] after Module3 recovered=%d\n", recovered); fflush(stderr);

    // Khôi phục lại scaling gốc
    s->progress_base = orig_base;
    s->progress_span = orig_span;

    // Free collector
    for (uint32_t i = 0; i < collector.count; i++) {
        if (collector.files[i].cluster_chain) free(collector.files[i].cluster_chain);
    }
    if (collector.files) free(collector.files);

    return recovered;
}

static int ReadSectorAt(int fd, int64_t sector, uint8_t* buf) {
    if (sector < 0) return 0;
    if (LSEEK(fd, sector * 512, SEEK_SET) < 0) return 0;
    return READ(fd, buf, 512) == 512;
}

// Thử phục hồi một phân vùng bắt đầu tại `base`.
//  1) Dùng VBR CHÍNH tại `base`.
//  2) Nếu VBR chính hỏng/không parse được → dùng BACKUP BOOT SECTOR
//     (exFAT: base+12, FAT32: base+6) NHƯNG vẫn giữ `base` là điểm bắt đầu
//     phân vùng thật (không lấy vị trí backup làm base — đây là bug cũ khiến
//     toàn bộ cluster-heap bị lệch và không ra file nào).
static int RecoverPartition(ScanSession* s, int64_t base, const char* out, int enable_fat, int scan_mode) {
    uint8_t vbr[512];

    if (ReadSectorAt(s->fd, base, vbr) && LooksLikeFsVbr(vbr)) {
        if (RecoverVolumeFiles(s, vbr, base, out, enable_fat, scan_mode) > 0) return 1;
    }

    // exFAT: backup boot region tại base+12 (nội dung giống hệt VBR chính).
    uint8_t bk[512];
    if (ReadSectorAt(s->fd, base + 12, bk) &&
        bk[510] == 0x55 && bk[511] == 0xAA &&
        memcmp(bk + 3, "EXFAT   ", 8) == 0) {
        if (RecoverVolumeFiles(s, bk, base, out, enable_fat, scan_mode) > 0) return 1;
    }

    // FAT32: backup boot sector mặc định tại base+6 (trường backup_boot_sector).
    if (ReadSectorAt(s->fd, base + 6, bk) &&
        LooksLikeFsVbr(bk) && memcmp(bk + 3, "EXFAT   ", 8) != 0) {
        if (RecoverVolumeFiles(s, bk, base, out, enable_fat, scan_mode) > 0) return 1;
    }

    return 0;
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

EXPORT int32_t recovery_scan(int32_t handle, const char* output_dir, RecoveryCallback callback, int32_t enable_fat, int32_t enable_carve, int32_t scan_mode) {
    if (handle < 0 || handle >= 8) return -1;
    ScanSession* s = &g_sessions[handle];
    s->cb         = callback;
    s->cancelled  = 0;
    s->start_ms   = NowMs();
    s->fat_count  = 0;
    s->carve_count = 0;
    s->progress_base = 0.0;
    // Carve chỉ thực sự chạy khi bật carve VÀ không phải chế độ quét nhanh (Existing).
    // Dùng chung biến này cho cả progress span, mốc kết thúc pha FS, và quyết định chạy
    // carve — tránh lệch pha khiến thanh tiến trình kẹt ở 24% khi quét nhanh.
    int32_t will_carve = (enable_carve && scan_mode != SCAN_MODE_EXISTING) ? 1 : 0;
    s->progress_span = will_carve ? 60.0 : 100.0;

    DiskGeometry geo;
    if (GetDiskGeometry(s->fd, &geo) < 0) {
        RecoveryEvent err = {0};
        err.event_type = EVENT_ERROR;
        err.error_code = -1;
        strncpy(err.error_msg, "Không thể lấy thông tin ổ đĩa", 255);
        PostEvent(s, &err);
        return -1;
    }

    s->total_sectors = geo.totalBytes / geo.bytesPerSector;
    size_t mask_size = (size_t)((s->total_sectors >> 3) + 1);
    s->sector_mask = (uint8_t*)calloc(mask_size, 1);

    if (enable_fat && !s->cancelled) {
        uint8_t sector[512];
        int found_fat = 0;

        // Tách hẳn output quét nhanh (cấu trúc FS) vào thư mục riêng để quét sâu (carve)
        // — vốn ghi vào <output_dir>\CARVED — không bao giờ chạm tới file quét nhanh.
        char fat_output_dir[1024];
        snprintf(fat_output_dir, sizeof(fat_output_dir), "%s%cSTRUCTURED", output_dir, FFI_PATH_SEP);

        EmitPhaseProgress(s, 0.5, 0, 0);

        // --- NEW: Partition Boundary Detection ---
        int64_t t_part_start = NowMs();
        PartitionCandidate candidates[16];
        int cand_count = DetectPartitions(s->fd, s->total_sectors, candidates, 16);
        fprintf(stderr, "[TIME] DetectPartitions took %lld ms (found %d candidates)\n", (long long)(NowMs() - t_part_start), cand_count); fflush(stderr);

        // Cập nhật tiến trình sau khi dò phân vùng
        EmitPhaseProgress(s, 2.0, 0, 0);

        int64_t t_fs_start = NowMs();
        for (int i = 0; i < cand_count; i++) {
            if (RecoverPartition(s, candidates[i].start_sector, fat_output_dir, enable_fat, scan_mode)) {
                found_fat = 1;
            }
        }
        fprintf(stderr, "[TIME] RecoverPartition loop took %lld ms\n", (long long)(NowMs() - t_fs_start)); fflush(stderr);

        if (!found_fat && LSEEK(s->fd, 0, SEEK_SET) == 0 && READ(s->fd, sector, 512) == 512) {
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
                                if (RecoverPartition(s, (int64_t)start_lba, fat_output_dir, enable_fat, scan_mode)) {
                                    found_fat = 1;
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
                    uint32_t start_lba = *((uint32_t*)&entry[8]);

                    // Bỏ qua entry rỗng, GPT protective (0xEE), và extended partition (0x05/0x0F).
                    if (type == 0x00 || type == 0xEE || type == 0x05 || type == 0x0F) continue;
                    if (start_lba == 0 || (int64_t)start_lba >= s->total_sectors) continue;

                    // Nhận diện & phục hồi qua VBR chính; nếu VBR chính hỏng,
                    // RecoverPartition tự động thử backup boot sector (exFAT +12 /
                    // FAT32 +6) với base đúng.
                    if (RecoverPartition(s, (int64_t)start_lba, fat_output_dir, enable_fat, scan_mode)) {
                        found_fat = 1;
                    }
                }
            }

            if (!found_fat && !s->cancelled) {
                if (RecoverPartition(s, 0, fat_output_dir, enable_fat, scan_mode)) {
                    found_fat = 1;
                }
            }
        }

        if (!found_fat && !s->cancelled) {
            // Fallback brute-force: dò VBR khi MBR/GPT không dùng được.
            // Lưu ý: partition thường bắt đầu ở 2048/8192/32768/65536... nên phải quét
            // ĐỦ XA và BAO GỒM biên (bug cũ dừng ở <32768 nên trượt VBR ở đúng sector 32768).
            int64_t scan_limit = 1048576; // tối đa 512MB đầu
            if (scan_limit > s->total_sectors) scan_limit = s->total_sectors;
            for (int64_t i = 1; i < scan_limit; i++) {
                if (s->cancelled) break;
                if (LSEEK(s->fd, i * 512, SEEK_SET) < 0) break;
                // Sector lỗi thì bỏ qua và đi tiếp thay vì dừng cả vòng dò.
                if (READ(s->fd, sector, 512) != 512) continue;

                if ((i & 8191) == 0) {
                    double pct = 12.0 + ((double)i / (double)scan_limit) * 28.0;
                    EmitPhaseProgress(s, pct, i * 512, 0);
                }

                if (LooksLikeFsVbr(sector)) {
                    // Thử coi sector này là VBR chính (base = i).
                    if (RecoverPartition(s, i, fat_output_dir, enable_fat, scan_mode)) {
                        found_fat = 1;
                        break;
                    }
                    // Hoặc đây là backup boot sector → base phân vùng thật nằm trước đó
                    // (exFAT: i-12, FAT32: i-6). Dùng chính nội dung sector này với base
                    // đã hiệu chỉnh thay vì lấy i làm base (bug cũ → lệch cluster-heap).
                    int is_exfat = memcmp(sector + 3, "EXFAT   ", 8) == 0;
                    int64_t real_base = i - (is_exfat ? 12 : 6);
                    if (real_base >= 0 &&
                        RecoverVolumeFiles(s, sector, real_base, fat_output_dir, enable_fat, scan_mode) > 0) {
                        found_fat = 1;
                        break;
                    }
                }
            }
        }

        // Kết thúc pha FS = phase 100%. Khi không carve → span 100 → 100%.
        // Khi có carve → span 60 → 60%, sau đó carve lấp 60..100 (đơn điệu, không tụt lùi).
        EmitPhaseProgress(s, 100.0, 0, 0);
    }

    if (will_carve && !s->cancelled) {
        int64_t t_carve_start = NowMs();
        double carve_start = 60.0; // FS scan chiếm 60%
        CarveFilesWithProgress(s->fd, geo.totalBytes, geo.bytesPerSector, output_dir, s, on_carve_progress, on_carve_file, &s->cancelled, carve_start, 100.0, s->sector_mask, s->reference_video[0] ? s->reference_video : NULL);
        fprintf(stderr, "[TIME] CarveFiles took %lld ms\n", (long long)(NowMs() - t_carve_start)); fflush(stderr);
    }

    if (s->sector_mask) {
        free(s->sector_mask);
        s->sector_mask = NULL;
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
        if (g_sessions[handle].sector_mask) {
            free(g_sessions[handle].sector_mask);
        }
        memset(&g_sessions[handle], 0, sizeof(ScanSession));
    }
}

EXPORT void recovery_free_string(char* ptr) {
    if (ptr) free(ptr);
}

EXPORT int32_t recovery_check_hardware(int32_t handle, HardwareHealthInfo* out_info) {
    if (handle < 0 || handle >= 8) return -1;
    return check_hardware_health(g_sessions[handle].fd, out_info);
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

EXPORT int32_t recovery_repair_video(const char* brokenPath, const char* referencePath, const char* outputPath) {
    return RepairVideo(brokenPath, referencePath, outputPath);
}

EXPORT char* recovery_identify_fs(int32_t handle) {
    if (handle < 0 || handle >= 8) return STRDUP("[]");
    ScanSession* s = &g_sessions[handle];
    uint8_t sector[512];
    char json[4096] = "[";
    int first = 1;

    // 1. Kiểm tra MBR
    if (LSEEK(s->fd, 0, SEEK_SET) == 0 && READ(s->fd, sector, 512) == 512) {
        if (sector[510] == 0x55 && sector[511] == 0xAA) {
            // Có thể là MBR hoặc VBR trực tiếp (superfloppy)
            int fsType = IdentifyFsFromVbr(sector);
            if (fsType != FS_TYPE_UNKNOWN) {
                snprintf(json + strlen(json), sizeof(json) - strlen(json),
                         "{\"offset\":0,\"type\":%d}", fsType);
                strcat(json, "]");
                return STRDUP(json);
            }

            // Quét MBR Partition Table
            for (int i = 0; i < 4; i++) {
                uint8_t* entry = &sector[446 + (i * 16)];
                uint32_t start_lba = *((uint32_t*)&entry[8]);
                if (start_lba == 0) continue;

                uint8_t vbr[512];
                if (LSEEK(s->fd, (int64_t)start_lba * 512, SEEK_SET) >= 0 && READ(s->fd, vbr, 512) == 512) {
                    int pType = IdentifyFsFromVbr(vbr);
                    if (pType == FS_TYPE_UNKNOWN && IsExt4(s->fd, (int64_t)start_lba)) pType = FS_TYPE_EXT4;

                    if (pType != FS_TYPE_UNKNOWN) {
                        if (!first) strcat(json, ",");
                        snprintf(json + strlen(json), sizeof(json) - strlen(json),
                                 "{\"offset\":%u,\"type\":%d}", start_lba, pType);
                        first = 0;
                    }
                }
            }
        }
    }

    // 2. Kiểm tra GPT (EFI PART at sector 1)
    if (LSEEK(s->fd, 512, SEEK_SET) == 512 && READ(s->fd, sector, 512) == 512) {
        if (memcmp(sector, "EFI PART", 8) == 0) {
            uint64_t table_lba = *((uint64_t*)&sector[72]);
            uint32_t num_entries = *((uint32_t*)&sector[80]);
            uint32_t entry_size = *((uint32_t*)&sector[84]);

            uint8_t entry[128]; // Giả định entry_size <= 128
            for (uint32_t i = 0; i < num_entries && i < 32; i++) { // Chỉ lấy 32 partition đầu
                if (LSEEK(s->fd, (table_lba * 512) + (i * entry_size), SEEK_SET) < 0) break;
                if (READ(s->fd, entry, entry_size) != (ssize_t)entry_size) break;

                uint64_t start_lba = *((uint64_t*)&entry[32]);
                if (start_lba == 0) continue;

                uint8_t vbr[512];
                if (LSEEK(s->fd, (int64_t)start_lba * 512, SEEK_SET) >= 0 && READ(s->fd, vbr, 512) == 512) {
                    int pType = IdentifyFsFromVbr(vbr);
                    if (pType == FS_TYPE_UNKNOWN && IsExt4(s->fd, (int64_t)start_lba)) pType = FS_TYPE_EXT4;

                    if (pType != FS_TYPE_UNKNOWN) {
                        if (!first) strcat(json, ",");
                        snprintf(json + strlen(json), sizeof(json) - strlen(json),
                                 "{\"offset\":%llu,\"type\":%d}", (unsigned long long)start_lba, pType);
                        first = 0;
                    }
                }
            }
        }
    }

    strcat(json, "]");
    return STRDUP(json);
}

EXPORT int32_t recovery_set_reference_video(int32_t handle, const char* referencePath) {
    if (handle < 0 || handle >= 8) return -1;
    ScanSession* s = &g_sessions[handle];
    if (referencePath && referencePath[0]) {
        strncpy(s->reference_video, referencePath, sizeof(s->reference_video) - 1);
        s->reference_video[sizeof(s->reference_video) - 1] = '\0';
    } else {
        s->reference_video[0] = '\0';
    }
    return 0;
}
