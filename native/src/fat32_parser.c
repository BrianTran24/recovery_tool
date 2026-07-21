#include "fat32_parser.h"
#include "platform_config.h"
#include "carver.h"
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#ifdef _WIN32
#include <direct.h>
#else
#include <sys/stat.h>
#endif

#ifdef _WIN32
#define PATH_SEP '\\'
#else
#define PATH_SEP '/'
#endif

// Recursive mkdir
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
    if (len >= 3 && isalpha(tmp[0]) && tmp[1] == ':' && tmp[2] == PATH_SEP) {
        p = tmp + 3;
    }
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

// Packed struct map thẳng vào 512 bytes đầu của disk
#pragma pack(push, 1)
typedef struct {
    uint8_t  jump_boot[3];       // EB 58 90 — jump instruction
    uint8_t  oem_name[8];        // "MSDOS5.0" hoặc "MSWIN4.1"

    // BPB cơ bản
    uint16_t bytes_per_sector;   // Thường 512
    uint8_t  sectors_per_cluster;// 8, 16, 32, 64 ... tùy dung lượng thẻ
    uint16_t reserved_sectors;   // Thường 32 cho FAT32
    uint8_t  num_fats;           // Luôn là 2
    uint16_t root_entry_count;   // 0 với FAT32
    uint16_t total_sectors_16;   // 0 với FAT32 (dùng total_sectors_32)
    uint8_t  media_type;         // 0xF8 = fixed, 0xF0 = removable
    uint16_t fat_size_16;        // 0 với FAT32
    uint16_t sectors_per_track;
    uint16_t num_heads;
    uint32_t hidden_sectors;
    uint32_t total_sectors_32;

    // BPB mở rộng FAT32
    uint32_t fat_size_32;        // Số sector mỗi bảng FAT
    uint16_t ext_flags;
    uint16_t fs_version;         // 0x0000
    uint32_t root_cluster;       // Cluster đầu của root dir, thường = 2
    uint16_t fs_info_sector;     // Thường = 1
    uint16_t backup_boot_sector; // Thường = 6
    uint8_t  reserved[12];
    uint8_t  drive_number;
    uint8_t  reserved1;
    uint8_t  boot_signature;     // 0x29
    uint32_t volume_id;
    uint8_t  volume_label[11];   // "NO NAME    "
    uint8_t  fs_type[8];         // "FAT32   "
} FAT32_BPB;
#pragma pack(pop)

// Thông số tính toán từ BPB — dùng xuyên suốt chương trình
typedef struct {
    uint32_t bytes_per_sector;
    uint32_t sectors_per_cluster;
    uint32_t bytes_per_cluster;
    uint32_t fat_start_sector;   // Sector bắt đầu FAT1
    uint32_t fat_size_sectors;   // Kích thước mỗi FAT (sectors)
    uint32_t data_start_sector;  // Sector bắt đầu Data region
    uint32_t root_cluster;       // Cluster đầu tiên của root dir
    uint32_t total_clusters;
    int64_t  baseSector;         // LBA bắt đầu của partition
} FAT32_Info;

int IsExFAT(const uint8_t* sector0) {
    return memcmp(sector0 + 3, "EXFAT   ", 8) == 0;
}

int ParseBPB(const uint8_t* sector0, FAT32_BPB* bpb, FAT32_Info* info) {
    // Kiểm tra sector có trống không (toàn 0)
    int all_zeros = 1;
    for (int i = 0; i < 512; i++) {
        if (sector0[i] != 0) {
            all_zeros = 0;
            break;
        }
    }

    if (all_zeros) return -2;

    if (IsExFAT(sector0)) return -3;

    memcpy(bpb, sector0, sizeof(FAT32_BPB));

    // Validate BPB cơ bản
    if (bpb->bytes_per_sector == 0 || bpb->sectors_per_cluster == 0) return -1;

    // Kiểm tra signature ở cuối sector (offset 510)
    if (sector0[510] != 0x55 || sector0[511] != 0xAA) return -1;

    if (bpb->bytes_per_sector != 512 && bpb->bytes_per_sector != 1024 && bpb->bytes_per_sector != 2048 && bpb->bytes_per_sector != 4096) return -1;

    if (bpb->sectors_per_cluster == 0 || (bpb->sectors_per_cluster & (bpb->sectors_per_cluster - 1)) != 0) return -1;

    // Tính các địa chỉ quan trọng
    info->bytes_per_sector    = bpb->bytes_per_sector;
    info->sectors_per_cluster = bpb->sectors_per_cluster;
    info->bytes_per_cluster   = bpb->bytes_per_sector * bpb->sectors_per_cluster;

    info->fat_start_sector    = bpb->reserved_sectors;
    info->fat_size_sectors    = bpb->fat_size_32;

    info->data_start_sector   = bpb->reserved_sectors
                                + (bpb->num_fats * bpb->fat_size_32);

    info->root_cluster        = bpb->root_cluster; // = 2
    info->total_clusters      = (bpb->total_sectors_32 - info->data_start_sector)
                                / bpb->sectors_per_cluster;

    return 0;
}

// FAT32 entry là 28-bit (4 byte, bỏ 4 bit cao)
#define FAT32_MASK        0x0FFFFFFF
#define FAT32_EOC         0x0FFFFFF8  // End of cluster chain
#define FAT32_FREE        0x00000000  // Cluster trống
#define FAT32_BAD         0x0FFFFFF7  // Bad cluster

uint32_t* LoadFATTable(int fd, const FAT32_Info* info) {
    uint32_t fatBytes = info->fat_size_sectors * info->bytes_per_sector;
    uint32_t* fat = (uint32_t*)malloc(fatBytes);
    if (!fat) return NULL;

    off_t_64 offset = (off_t_64)info->fat_start_sector * info->bytes_per_sector;
    if (LSEEK(fd, offset, SEEK_SET) < 0 || READ(fd, fat, fatBytes) != (ssize_t)fatBytes) {
        // Vùng FAT hỏng/không đọc được (thẻ lỗi ghi): zero-fill để coi mọi cluster là
        // FREE. Nhờ đó pha "hunt" bên dưới quét toàn bộ cluster-heap và dựng lại cây
        // thư mục trực tiếp từ directory entry (metadata) — giống cách DMDE quét nhanh.
        memset(fat, 0, fatBytes);
    }

    return fat; // Caller chịu trách nhiệm free()
}

// Tra cứu cluster tiếp theo trong chain
uint32_t FATNextCluster(const uint32_t* fat, uint32_t cluster) {
    return fat[cluster] & FAT32_MASK;
}

// Kiểm tra cluster đã free (entry = 0x00 sau khi file bị xóa)
int IsClusterFree(const uint32_t* fat, uint32_t cluster) {
    return (fat[cluster] & FAT32_MASK) == FAT32_FREE;
}

// Tính sector đầu tiên của cluster N (Tuyệt đối trên đĩa)
uint32_t ClusterToSector(const FAT32_Info* info, uint32_t cluster) {
    // Cluster 2 = data_start_sector (cluster đánh số từ 2)
    return (uint32_t)info->baseSector + info->data_start_sector
           + (cluster - 2) * info->sectors_per_cluster;
}

#pragma pack(push, 1)
typedef struct {
    uint8_t  name[8];            // Tên file, space-padded
    uint8_t  ext[3];             // Phần mở rộng
    uint8_t  attributes;         // ATTR_READ_ONLY=0x01, ATTR_DIRECTORY=0x10...
    uint8_t  reserved;
    uint8_t  create_time_tenth;
    uint16_t create_time;
    uint16_t create_date;
    uint16_t last_access_date;
    uint16_t first_cluster_high; // 2 byte cao của cluster đầu tiên
    uint16_t write_time;
    uint16_t write_date;
    uint16_t first_cluster_low;  // 2 byte thấp của cluster đầu tiên
    uint32_t file_size;          // Kích thước file (byte)
} FAT32_DirEntry;
#pragma pack(pop)

// Attributes
#define ATTR_READ_ONLY  0x01
#define ATTR_HIDDEN     0x02
#define ATTR_SYSTEM     0x04
#define ATTR_VOLUME_ID  0x08
#define ATTR_DIRECTORY  0x10
#define ATTR_ARCHIVE    0x20
#define ATTR_LFN        0x0F  // Long filename entry — bỏ qua khi scan

// Lấy cluster đầu từ directory entry
uint32_t GetFirstCluster(const FAT32_DirEntry* entry) {
    return ((uint32_t)entry->first_cluster_high << 16)
           | entry->first_cluster_low;
}

// Kiểm tra entry có phải file phù hợp với chế độ quét không
int MatchFile(const FAT32_DirEntry* entry, int scan_mode) {
    if (entry->attributes == ATTR_LFN) return 0;
    if (entry->attributes & ATTR_DIRECTORY) return 0;
    if (entry->file_size == 0) return 0;
    if (GetFirstCluster(entry) < 2) return 0;

    int isDeleted = (entry->name[0] == 0xE5);

    if (scan_mode == 1) return isDeleted;      // SCAN_MODE_DELETED
    if (scan_mode == 2) return !isDeleted;     // SCAN_MODE_EXISTING
    return 1;                                 // SCAN_MODE_BOTH
}

typedef struct {
    uint16_t name[260];
    int      expected_seq;
    uint8_t  checksum;
    int      is_valid;
} LFN_State;

static void ResetLFN(LFN_State* lfn) {
    memset(lfn, 0, sizeof(LFN_State));
    lfn->expected_seq = -1;
}

static uint8_t CalculateChecksum(const uint8_t* shortName) {
    uint8_t sum = 0;
    for (int i = 11; i > 0; i--) {
        sum = ((sum & 1) ? 0x80 : 0) + (sum >> 1) + *shortName++;
    }
    return sum;
}

static void ProcessLFNEntry(const uint8_t* entry, LFN_State* lfn) {
    uint8_t seq = entry[0];
    if (seq & 0x40) { // First LFN entry (last part of name)
        ResetLFN(lfn);
        lfn->expected_seq = seq & 0x1F;
        lfn->checksum = entry[13];
        lfn->is_valid = 1;
    } else if (!lfn->is_valid || seq != lfn->expected_seq - 1 || entry[13] != lfn->checksum) {
        lfn->is_valid = 0;
        return;
    }

    lfn->expected_seq = seq & 0x1F;
    int start_index = (lfn->expected_seq - 1) * 13;
    if (start_index + 13 > 255) {
        lfn->is_valid = 0;
        return;
    }

    const uint8_t* p = entry + 1;
    for (int i = 0; i < 5; i++) lfn->name[start_index++] = p[i*2] | (p[i*2+1] << 8);
    p = entry + 14;
    for (int i = 0; i < 6; i++) lfn->name[start_index++] = p[i*2] | (p[i*2+1] << 8);
    p = entry + 28;
    for (int i = 0; i < 2; i++) lfn->name[start_index++] = p[i*2] | (p[i*2+1] << 8);
}

static void GetLFN(LFN_State* lfn, const uint8_t* shortName, char* out, size_t outSize) {
    if (!lfn->is_valid || lfn->expected_seq != 1 || lfn->checksum != CalculateChecksum(shortName)) {
        out[0] = '\0';
        return;
    }

    size_t written = 0;
    for (int i = 0; i < 255 && lfn->name[i] != 0 && written + 4 < outSize; i++) {
        uint16_t cp = lfn->name[i];
        if (cp < 0x80) {
            out[written++] = (char)cp;
        } else if (cp < 0x800) {
            out[written++] = (char)(0xC0 | (cp >> 6));
            out[written++] = (char)(0x80 | (cp & 0x3F));
        } else {
            out[written++] = (char)(0xE0 | (cp >> 12));
            out[written++] = (char)(0x80 | ((cp >> 6) & 0x3F));
            out[written++] = (char)(0x80 | (cp & 0x3F));
        }
    }
    out[written] = '\0';
}

// Build tên file từ entry
void GetFileName(const FAT32_DirEntry* entry, LFN_State* lfn, char* out, size_t outSize) {
    GetLFN(lfn, (const uint8_t*)entry, out, outSize);
    if (out[0] != '\0') return;

    char name[9] = {0};
    char ext[4]  = {0};

    for (int i = 0; i < 8; i++) {
        if (i == 0 && entry->name[0] == 0xE5) {
            name[0] = '_';
        } else {
            name[i] = (entry->name[i] == ' ') ? '\0' : entry->name[i];
        }
    }
    for (int i = 0; i < 3; i++) {
        ext[i] = (entry->ext[i] == ' ') ? '\0' : entry->ext[i];
    }

    if (ext[0])
        snprintf(out, outSize, "%s.%s", name, ext);
    else
        snprintf(out, outSize, "%s", name);
}


typedef struct {
    char     filename[64];
    uint32_t first_cluster;
    uint32_t file_size;
    uint16_t write_date;
    uint16_t write_time;
} DeletedFileInfo;

static void FormatFatTimestamp(uint16_t date, uint16_t time, char* out, size_t outSize) {
    uint32_t year = ((uint32_t)(date >> 9) & 0x7F) + 1980U;
    uint32_t month = ((uint32_t)(date >> 5) & 0x0F);
    uint32_t day = (uint32_t)(date & 0x1F);
    uint32_t hour = ((uint32_t)(time >> 11) & 0x1F);
    uint32_t minute = ((uint32_t)(time >> 5) & 0x3F);
    uint32_t second = ((uint32_t)(time & 0x1F) * 2U);

    if (year < 1980U || month == 0U || month > 12U || day == 0U || day > 31U) {
        if (outSize > 0) out[0] = '\0';
        return;
    }

    snprintf(out, outSize, "%04u-%02u-%02u %02u:%02u:%02u", year, month, day, hour, minute, second);
}

static void EmitFatProgress(FatProgressCallback on_progress, void* context, uint32_t total_clusters, int visited_clusters, double progress_start, double progress_end, int64_t scanned_bytes) {
    if (!on_progress) return;

    double ratio = 0.0;
    if (total_clusters > 0) {
        ratio = (double)visited_clusters / (double)total_clusters;
    }
    double pct = progress_start + ratio * (progress_end - progress_start);
    if (pct > progress_end) pct = progress_end;
    on_progress(context, pct, scanned_bytes, 0);
}

// Đọc một cluster vào buffer
int ReadCluster(int fd, const FAT32_Info* info,
                uint32_t cluster, uint8_t* buffer) {
    uint32_t sector = ClusterToSector(info, cluster);
    off_t_64 offset = (off_t_64)sector * info->bytes_per_sector;
    if (LSEEK(fd, offset, SEEK_SET) < 0) return -1;
    ssize_t n = READ(fd, buffer, info->bytes_per_cluster);
    return (n == (ssize_t)info->bytes_per_cluster) ? 0 : -1;
}

// Forward declarations
void ScanDirectory(int fd, const FAT32_Info* info,
                   const uint32_t* fat,
                   uint32_t startCluster,
                   uint8_t* clusterBuf,
                   void* context,
                   FatFileCallback on_file,
                   FatProgressCallback on_progress,
                   double progress_start,
                   double progress_end,
                   int* visited_clusters,
                   const char* outputDir,
                   const char* relPath,
                   volatile int* cancelled,
                   int* recoveredCount,
                   int scan_mode);

#ifdef _WIN32
#define PATH_SEP_UNUSED '\\'
#else
#define PATH_SEP_UNUSED '/'
#endif

// Scan một directory cluster — tìm entry có 0xE5
static void ScanDirectoryCluster(int fd, const FAT32_Info* info,
                          const uint32_t* fat,
                          uint32_t cluster,
                          uint8_t* clusterBuf,
                          void* context,
                          FatFileCallback on_file,
                          FatProgressCallback on_progress,
                          double progress_start,
                          double progress_end,
                          int* visited_clusters,
                          const char* outputDir,
                          const char* relPath,
                          volatile int* cancelled,
                          int* recoveredCount,
                          int scan_mode) {
    uint32_t entriesPerCluster = info->bytes_per_cluster / sizeof(FAT32_DirEntry);
    FAT32_DirEntry* entries = (FAT32_DirEntry*)clusterBuf;
    LFN_State lfn = {0};
    lfn.expected_seq = -1;

    for (uint32_t i = 0; i < entriesPerCluster; i++) {
        if (cancelled && *cancelled) return;
        FAT32_DirEntry* e = &entries[i];

        if (e->name[0] == 0x00) break; // Hết directory

        if (e->attributes == ATTR_LFN) {
            ProcessLFNEntry((const uint8_t*)e, &lfn);
            continue;
        }

        if (MatchFile(e, scan_mode)) {
            char filename[256];
            GetFileName(e, &lfn, filename, sizeof(filename));
            uint32_t first_cluster = GetFirstCluster(e);
            char modifiedTime[32] = {0};
            FormatFatTimestamp(e->write_date, e->write_time, modifiedTime, sizeof(modifiedTime));

            int isDeleted = (e->name[0] == 0xE5);
            uint32_t sector_offset = ClusterToSector(info, first_cluster);

            char displayPath[512];
            if (relPath && relPath[0]) {
                snprintf(displayPath, sizeof(displayPath), "%s%c%s", relPath, PATH_SEP, filename);
            } else {
                snprintf(displayPath, sizeof(displayPath), "%s", filename);
            }

            char outPath[1024];
            if (isDeleted) {
                // Deleted files go to a special folder to avoid name collisions with live files
                char delDir[1024];
                snprintf(delDir, sizeof(delDir), "%s%cDELETED", outputDir, PATH_SEP);
                mkdir_p(delDir);
                snprintf(outPath, sizeof(outPath), "%s%c%u_%s", delDir, PATH_SEP, sector_offset, filename);
            } else {
                mkdir_p(outputDir);
                snprintf(outPath, sizeof(outPath), "%s%c%s", outputDir, PATH_SEP, filename);
            }

            // Recover file
            FILE* out = fopen(outPath, "wb");
            if (out) {
                uint8_t* fileBuf = (uint8_t*)malloc(info->bytes_per_cluster);
                uint32_t remaining = e->file_size;
                uint32_t curr = first_cluster;
                int useFATChain = !IsClusterFree(fat, curr);
                double last_entropy = -1.0;

                while (remaining > 0 && curr >= 2 && curr < 0x0FFFFFF8) {
                    if (ReadCluster(fd, info, curr, fileBuf) < 0) break;

                    // GUIDED CARVING: Kiểm tra phân mảnh nếu là file xóa
                    if (isDeleted && !useFATChain) {
                        // 1. Kiểm tra nếu cluster hiện tại chứa header của file khác
                        if (is_cluster_header(fileBuf, info->bytes_per_cluster)) {
                            printf("DEBUG: FAT32 Guided Carving - Fragmentation detected at cluster %u (Found new header). Searching for next free cluster...\n", curr);
                            // Tìm cluster FREE tiếp theo có entropy tương đồng (nếu có thể)
                            uint32_t next_gap = curr + 1;
                            int found_gap = 0;
                            while (next_gap < info->total_clusters + 2 && next_gap < curr + 1024) { // Giới hạn tìm kiếm 1024 clusters
                                if (IsClusterFree(fat, next_gap)) {
                                    // Ở đây có thể thêm kiểm tra entropy nếu muốn chính xác hơn
                                    curr = next_gap;
                                    found_gap = 1;
                                    break;
                                }
                                next_gap++;
                            }
                            if (!found_gap) break; // Không tìm thấy vùng trống nào tiếp theo
                            if (ReadCluster(fd, info, curr, fileBuf) < 0) break;
                        }

                        // 2. Kiểm tra Entropy (nếu file đủ lớn và không phải cluster đầu)
                        if (last_entropy > 0 && remaining > info->bytes_per_cluster) {
                            double current_entropy = calculate_entropy(fileBuf, info->bytes_per_cluster);
                            // Nếu entropy thay đổi quá đột ngột (> 50% cho dữ liệu nén/phức tạp), có thể là vùng rác
                            if (last_entropy > 6.0 && current_entropy < 4.0) {
                                printf("DEBUG: FAT32 Guided Carving - Low entropy detected at cluster %u (%.2f vs %.2f). Potential fragment end.\n", curr, current_entropy, last_entropy);
                                // Có thể thử tìm cluster tiếp theo hoặc dừng lại
                            }
                            last_entropy = current_entropy;
                        } else {
                            last_entropy = calculate_entropy(fileBuf, info->bytes_per_cluster);
                        }
                    }

                    uint32_t writeSize = (remaining < info->bytes_per_cluster) ? remaining : info->bytes_per_cluster;
                    fwrite(fileBuf, 1, writeSize, out);
                    remaining -= writeSize;

                    if (useFATChain) {
                        curr = FATNextCluster(fat, curr);
                    } else {
                        curr++;
                        // If we are following a "ghost" chain (deleted file),
                        // stop if we hit a cluster that is actually in use by another file.
                        if (curr < info->total_clusters + 2 && !IsClusterFree(fat, curr)) {
                            // Cố gắng nhảy qua vùng đang bận (Gap Search)
                            uint32_t jump = curr;
                            int jumped = 0;
                            while (jump < info->total_clusters + 2 && jump < curr + 512) {
                                if (IsClusterFree(fat, jump)) {
                                    curr = jump;
                                    jumped = 1;
                                    break;
                                }
                                jump++;
                            }
                            if (!jumped) break;
                        }
                    }
                    if (cancelled && *cancelled) break;
                }
                fclose(out);
                free(fileBuf);

                if (on_file) {
                    int64_t num_clusters = (e->file_size + info->bytes_per_cluster - 1) / info->bytes_per_cluster;
                    int64_t sector_count = num_clusters * info->sectors_per_cluster;
                    on_file(context, (isDeleted ? "FAT_DEL" : "FAT"), displayPath, modifiedTime, (int64_t)e->file_size, (int64_t)sector_offset, sector_count, "");
                }
                (*recoveredCount)++;
                if (visited_clusters) {
                EmitFatProgress(on_progress, context, info->total_clusters, *visited_clusters, progress_start, progress_end, (int64_t)(*visited_clusters) * info->bytes_per_cluster);
                }
            } else {
                printf("ERROR: FAT32 could not open file for writing: %s\n", outPath);
            }
        }

        // Nếu là thư mục còn sống (không bị xóa) → đi vào đệ quy
        if (e->name[0] != 0xE5
            && (e->attributes & ATTR_DIRECTORY)
            && !(e->attributes & ATTR_VOLUME_ID)
            && e->name[0] != '.') {
            uint32_t subCluster = GetFirstCluster(e);
            char subDir[1024];
            char subFolderName[256];
            LFN_State tempLfn = lfn; // Use current LFN for the folder name
            GetFileName(e, &tempLfn, subFolderName, sizeof(subFolderName));
            snprintf(subDir, sizeof(subDir), "%s%c%s", outputDir, PATH_SEP, subFolderName);

            char subRelPath[512];
            if (relPath && relPath[0]) {
                snprintf(subRelPath, sizeof(subRelPath), "%s%c%s", relPath, PATH_SEP, subFolderName);
            } else {
                snprintf(subRelPath, sizeof(subRelPath), "%s", subFolderName);
            }

            // Cần buffer riêng cho đệ quy để không ghi đè buffer hiện tại
            uint8_t* subBuf = (uint8_t*)malloc(info->bytes_per_cluster);
            ScanDirectory(fd, info, fat, subCluster, subBuf, context, on_file, on_progress, progress_start, progress_end, visited_clusters, subDir, subRelPath, cancelled, recoveredCount, scan_mode);
            free(subBuf);
        }

        // Reset LFN for next entry if it wasn't an LFN entry
        ResetLFN(&lfn);
    }
}

// Scan toàn bộ directory (follow cluster chain)
static void AddToFileCollector(FileCollector* collector, FileInfo* info) {
    // 1. Kiểm tra trùng lặp dựa trên starting_cluster
    for (uint32_t i = 0; i < collector->count; i++) {
        if (collector->files[i].starting_cluster == info->starting_cluster) {
            // Đã tồn tại, giải phóng cluster_chain (nếu có) và bỏ qua
            if (info->cluster_chain) {
                free(info->cluster_chain);
                info->cluster_chain = NULL;
            }
            return;
        }
    }

    // 2. Thêm file mới
    if (collector->count >= collector->capacity) {
        uint32_t newCap = collector->capacity == 0 ? 128 : collector->capacity * 2;
        FileInfo* grown = (FileInfo*)realloc(collector->files, newCap * sizeof(FileInfo));
        if (!grown) return;
        collector->files = grown;
        collector->capacity = newCap;
    }
    collector->files[collector->count++] = *info;
}

static void PopulateFileInfo(FileInfo* info, const FAT32_DirEntry* e, LFN_State* lfn, const char* relPath, int status) {
    memset(info, 0, sizeof(FileInfo));
    GetFileName(e, lfn, info->filename, sizeof(info->filename));
    info->starting_cluster = GetFirstCluster(e);
    if (info->filename[0] == '\0') {
        snprintf(info->filename, sizeof(info->filename), "FILE_%u", info->starting_cluster);
    }
    if (relPath) snprintf(info->rel_path, sizeof(info->rel_path), "%s", relPath);
    FormatFatTimestamp(e->write_date, e->write_time, info->modified_time, sizeof(info->modified_time));
    info->file_size = (int64_t)e->file_size;
    info->status = status;
    info->is_deleted = (e->name[0] == 0xE5);
}

// Giới hạn độ sâu đệ quy thư mục để chống stack-overflow trên FS hỏng/cross-linked.
#define FAT32_MAX_DIR_DEPTH 100

// Bitmap "visited" theo cluster thư mục đã duyệt — chống đệ quy vô hạn (vòng lặp,
// cross-link) và chống thu thập trùng lặp giữa các pha quét.
static inline int VisitedTest(const uint8_t* v, uint32_t c) {
    return v ? (v[c >> 3] & (1 << (c & 7))) : 0;
}
static inline void VisitedSet(uint8_t* v, uint32_t c) {
    if (v) v[c >> 3] |= (uint8_t)(1 << (c & 7));
}

static void CollectFromCluster(int fd, const FAT32_Info* info, const uint32_t* fat, uint32_t cluster, uint8_t* clusterBuf, FileCollector* collector, const char* relPath, volatile int* cancelled, int scan_mode, uint8_t* visited, int depth);

static void CollectFromDirectory(int fd, const FAT32_Info* info, const uint32_t* fat, uint32_t startCluster, uint8_t* clusterBuf, FileCollector* collector, const char* relPath, volatile int* cancelled, int scan_mode, uint8_t* visited, int depth) {
    if (depth > FAT32_MAX_DIR_DEPTH) return;
    uint32_t cluster = startCluster;
    int maxChain = 65536;
    while (cluster >= 2 && cluster < 0x0FFFFFF8 && maxChain-- > 0) {
        if (cancelled && *cancelled) return;
        // Nếu cluster thư mục này đã được duyệt → gặp vòng lặp/cross-link, dừng lại
        // để không đệ quy vô hạn và không thu thập trùng (rò rỉ cluster_chain).
        if (cluster < info->total_clusters + 2) {
            if (VisitedTest(visited, cluster)) return;
            VisitedSet(visited, cluster);
        }
        if (ReadCluster(fd, info, cluster, clusterBuf) == 0) {
            CollectFromCluster(fd, info, fat, cluster, clusterBuf, collector, relPath, cancelled, scan_mode, visited, depth);
        }
        cluster = FATNextCluster(fat, cluster);
    }
}

static void CollectFromCluster(int fd, const FAT32_Info* info, const uint32_t* fat, uint32_t cluster, uint8_t* clusterBuf, FileCollector* collector, const char* relPath, volatile int* cancelled, int scan_mode, uint8_t* visited, int depth) {
    uint32_t entriesPerCluster = info->bytes_per_cluster / sizeof(FAT32_DirEntry);
    FAT32_DirEntry* entries = (FAT32_DirEntry*)clusterBuf;
    LFN_State lfn = {0};
    lfn.expected_seq = -1;

    for (uint32_t i = 0; i < entriesPerCluster; i++) {
        if (cancelled && *cancelled) return;
        FAT32_DirEntry* e = &entries[i];
        if (e->name[0] == 0x00) break;

        if (e->attributes == ATTR_LFN) {
            ProcessLFNEntry((const uint8_t*)e, &lfn);
            continue;
        }

        if (MatchFile(e, scan_mode)) {
            FileInfo fi;
            PopulateFileInfo(&fi, e, &lfn, relPath, FILE_STATUS_HEALTHY);

            // For healthy files, we can follow the FAT chain if the file is NOT deleted
            // or if the FAT chain is still valid (rare for deleted files but possible).
            if (!fi.is_deleted) {
                // Count chain length
                uint32_t curr = fi.starting_cluster;
                uint32_t len = 0;
                while (curr >= 2 && curr < 0x0FFFFFF8 && len < 1000000) { // Safety limit
                    len++;
                    curr = FATNextCluster(fat, curr);
                }
                if (len > 0) {
                    fi.chain_length = len;
                    fi.cluster_chain = (uint32_t*)malloc(len * sizeof(uint32_t));
                    curr = fi.starting_cluster;
                    for (uint32_t j = 0; j < len; j++) {
                        fi.cluster_chain[j] = curr;
                        curr = FATNextCluster(fat, curr);
                    }
                }
            }
            AddToFileCollector(collector, &fi);
        }

        if (e->name[0] != 0xE5 && (e->attributes & ATTR_DIRECTORY) && !(e->attributes & ATTR_VOLUME_ID) && e->name[0] != '.') {
            uint32_t subCluster = GetFirstCluster(e);
            char subFolderName[256];
            LFN_State tempLfn = lfn;
            GetFileName(e, &tempLfn, subFolderName, sizeof(subFolderName));

            char subRelPath[512];
            if (relPath && relPath[0]) snprintf(subRelPath, sizeof(subRelPath), "%s%c%s", relPath, PATH_SEP, subFolderName);
            else snprintf(subRelPath, sizeof(subRelPath), "%s", subFolderName);

            uint8_t* subBuf = (uint8_t*)malloc(info->bytes_per_cluster);
            if (subBuf) {
                CollectFromDirectory(fd, info, fat, subCluster, subBuf, collector, subRelPath, cancelled, scan_mode, visited, depth + 1);
                free(subBuf);
            }
        }
        ResetLFN(&lfn);
    }
}

static void ScanDirectoryCluster(int fd, const FAT32_Info* info,
                          const uint32_t* fat,
                          uint32_t cluster,
                          uint8_t* clusterBuf,
                          void* context,
                          FatFileCallback on_file,
                          FatProgressCallback on_progress,
                          double progress_start,
                          double progress_end,
                          int* visited_clusters,
                          const char* outputDir,
                          const char* relPath,
                          volatile int* cancelled,
                          int* recoveredCount,
                          int scan_mode);

static void ScanDirectory(int fd, const FAT32_Info* info,
                   const uint32_t* fat,
                   uint32_t startCluster,
                   uint8_t* clusterBuf,
                   void* context,
                   FatFileCallback on_file,
                   FatProgressCallback on_progress,
                   double progress_start,
                   double progress_end,
                   int* visited_clusters,
                   const char* outputDir,
                   const char* relPath,
                   volatile int* cancelled,
                   int* recoveredCount,
                   int scan_mode) {
    uint32_t cluster = startCluster;
    int maxChain = 65536;

    while (cluster >= 2 && cluster < 0x0FFFFFF8 && maxChain-- > 0) {
        if (cancelled && *cancelled) return;
        if (ReadCluster(fd, info, cluster, clusterBuf) == 0) {
            if (visited_clusters) {
                (*visited_clusters)++;
                EmitFatProgress(on_progress, context, info->total_clusters, *visited_clusters, progress_start, progress_end, (int64_t)(cluster - 2) * info->bytes_per_cluster);
            }
            ScanDirectoryCluster(fd, info, fat, cluster,
                                 clusterBuf, context, on_file, on_progress, progress_start, progress_end, visited_clusters, outputDir, relPath, cancelled, recoveredCount, scan_mode);
        }
        cluster = FATNextCluster(fat, cluster);
    }
}

static int IsFatDirCluster(const uint8_t* buf, uint32_t sz) {
    int dirEntries = 0;
    for (uint32_t off = 0; off + 32 <= sz; off += 32) {
        const uint8_t* e = buf + off;
        // Kiểm tra attributes và cấu trúc cơ bản của FAT dir entry
        if (e[0] == 0x00) break;
        if (e[11] == 0x0F) continue; // LFN
        if (e[11] & 0x08) continue;  // Volume ID
        // Nếu cluster đầu hợp lệ và kích thước file hợp lý cho dir
        uint32_t first = ((uint32_t)e[20] << 16) | e[26];
        if (first >= 2) dirEntries++;
    }
    return (dirEntries >= 1);
}

void CollectHealthyFilesFat32(int fd, int64_t baseSector, const uint8_t* sector0, FileCollector* collector, void* context, FatProgressCallback on_progress, volatile int* cancelled, int scan_mode) {
    FAT32_BPB bpb;
    FAT32_Info info;
    if (ParseBPB(sector0, &bpb, &info) < 0) return;
    info.baseSector = baseSector;

    uint32_t* fat = LoadFATTable(fd, &info);
    if (!fat) return;

    uint8_t* clusterBuf = (uint8_t*)malloc(info.bytes_per_cluster);
    if (!clusterBuf) { free(fat); return; }

    // Bitmap visited để chống vòng lặp thư mục
    uint8_t* visited = (uint8_t*)calloc(((size_t)info.total_clusters + 2) / 8 + 1, 1);

    // Duyệt cây thư mục từ Root.
    CollectFromDirectory(fd, &info, fat, info.root_cluster, clusterBuf, collector, "", cancelled, scan_mode, visited, 0);

    if (visited) free(visited);
    free(clusterBuf);
    free(fat);
}

void ScanOrphanedEntriesFat32(int fd, int64_t baseSector, const uint8_t* sector0, FileCollector* collector, void* context, FatProgressCallback on_progress, volatile int* cancelled) {
    FAT32_BPB bpb;
    FAT32_Info info;
    if (ParseBPB(sector0, &bpb, &info) < 0) return;
    info.baseSector = baseSector;

    uint32_t* fat = LoadFATTable(fd, &info);
    if (!fat) return;

    uint8_t* clusterBuf = (uint8_t*)malloc(info.bytes_per_cluster);
    if (!clusterBuf) { free(fat); return; }

    // Bitmap visited để tránh quét lại các cluster đã xử lý
    uint8_t* visited = (uint8_t*)calloc(((size_t)info.total_clusters + 2) / 8 + 1, 1);
    LFN_State lfn = {0};
    lfn.expected_seq = -1;

    if (clusterBuf && visited) {
        for (uint32_t c = 2; c < info.total_clusters + 2 && (!cancelled || !*cancelled); c++) {
            if (VisitedTest(visited, c)) continue;

            if (ReadCluster(fd, &info, c, clusterBuf) == 0) {
                // 1. Kiểm tra nếu cluster trông giống thư mục (Lost Directory)
                if (IsFatDirCluster(clusterBuf, info.bytes_per_cluster)) {
                    char folderName[32]; snprintf(folderName, sizeof(folderName), "found_%u", c);
                    CollectFromCluster(fd, &info, fat, c, clusterBuf, collector, folderName, cancelled, SCAN_MODE_BOTH, visited, 0);
                } else {
                    // 2. Quét từng entry lẻ (Orphaned Files)
                    FAT32_DirEntry* entries = (FAT32_DirEntry*)clusterBuf;
                    for (uint32_t i = 0; i < info.bytes_per_cluster / 32; i++) {
                        FAT32_DirEntry* e = &entries[i];
                        if (e->name[0] == 0x00) break;
                        if (e->attributes == ATTR_LFN) {
                            ProcessLFNEntry((const uint8_t*)e, &lfn);
                            continue;
                        }

                        if (MatchFile(e, SCAN_MODE_BOTH)) {
                            FileInfo fi;
                            PopulateFileInfo(&fi, e, &lfn, "ORPHANED", FILE_STATUS_ORPHANED);
                            AddToFileCollector(collector, &fi);
                        }
                        ResetLFN(&lfn);
                    }
                }
            }
            if (on_progress && (c % 10000 == 0)) {
                on_progress(context, ((double)c / info.total_clusters) * 100.0, (int64_t)c * info.bytes_per_cluster, 0);
            }
        }
    }

    free(clusterBuf);
    free(fat);
    if (visited) free(visited);
}

int RecoverAllFiles(int fd, int64_t baseSector, const uint8_t* sector0,
                           const char* outputDir, void* context, FatFileCallback on_file, FatProgressCallback on_progress, volatile int* cancelled, int scan_mode) {
    // 1. Parse BPB
    FAT32_BPB bpb;
    FAT32_Info info;
    if (ParseBPB(sector0, &bpb, &info) < 0) return 0;
    info.baseSector = baseSector;

    // 2. Load FAT table
    uint32_t* fat = LoadFATTable(fd, &info);
    if (!fat) return 0;

    // 3. Alloc cluster buffer
    uint8_t* clusterBuf = (uint8_t*)malloc(info.bytes_per_cluster);
    if (!clusterBuf) {
        free(fat);
        return 0;
    }

    MKDIR(outputDir, 0755);

    int recoveredCount = 0;
    int visited_clusters = 0;
    // 5. Bắt đầu scan từ root directory (cluster 2)
    ScanDirectory(fd, &info, fat, info.root_cluster,
                  clusterBuf, context, on_file, on_progress, 0.0, 30.0, &visited_clusters, outputDir, "", cancelled, &recoveredCount, scan_mode);

    // 6. Directory Hunting cho FAT32 (Tương tự exFAT)
    for (uint32_t c = 2; c < info.total_clusters + 2 && (!cancelled || !*cancelled); c++) {
        // Chỉ quét các cluster được đánh dấu là FREE trong FAT để tìm thư mục đã bị format/xóa
        if (IsClusterFree(fat, c)) {
            if (ReadCluster(fd, &info, c, clusterBuf) == 0) {
                if (IsFatDirCluster(clusterBuf, info.bytes_per_cluster)) {
                    char folderName[32]; snprintf(folderName, sizeof(folderName), "found_%u", c);
                    // useFatChain = 0 vì là thư mục mồ côi
                    ScanDirectoryCluster(fd, &info, fat, c, clusterBuf, context, on_file, on_progress, 30.0, 100.0, NULL, outputDir, folderName, cancelled, &recoveredCount, scan_mode);
                }
            }
        }
        if (on_progress && (c % 2000 == 0)) {
            double pct = 30.0 + ((double)c / info.total_clusters) * 70.0;
            on_progress(context, pct, (int64_t)c * info.bytes_per_cluster, 0);
        }
    }


    free(clusterBuf);
    free(fat);
    return recoveredCount;
}
