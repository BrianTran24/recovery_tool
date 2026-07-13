#include "fat32_parser.h"
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

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

    // Log 32 bytes đầu để debug cực kỳ chi tiết
    printf("DEBUG: Parsing sector. All zeros: %s. Hex: ", all_zeros ? "YES" : "NO");
    for(int i=0; i<32; i++) printf("%02X ", sector0[i]);
    printf("... Sig: %02X %02X\n", sector0[510], sector0[511]);

    if (all_zeros) {
        return -2; // Mã lỗi đặc biệt cho sector trống
    }

    if (IsExFAT(sector0)) {
        printf("DEBUG: Detected exFAT signature\n");
        return -3; // Mã lỗi cho exFAT
    }

    memcpy(bpb, sector0, sizeof(FAT32_BPB));

    // Validate BPB cơ bản
    if (bpb->bytes_per_sector == 0 || bpb->sectors_per_cluster == 0) {
        printf("DEBUG: BPB Invalid - bytes_per_sector: %u, sectors_per_cluster: %u\n",
               bpb->bytes_per_sector, bpb->sectors_per_cluster);
        return -1;
    }

    // Kiểm tra signature ở cuối sector (offset 510)
    if (sector0[510] != 0x55 || sector0[511] != 0xAA) {
        printf("DEBUG: Missing 0x55AA signature at end of sector\n");
        return -1;
    }

    // Thử tin vào bytes_per_sector và sectors_per_cluster nếu signature 0x55AA tồn tại
    // Nhiều SD card hiện đại có BPB không chuẩn nhưng dữ liệu vẫn đúng
    if (bpb->bytes_per_sector != 512 && bpb->bytes_per_sector != 1024 && bpb->bytes_per_sector != 2048 && bpb->bytes_per_sector != 4096) {
        printf("DEBUG: Unusual bytes_per_sector: %u\n", bpb->bytes_per_sector);
        return -1;
    }

    if (bpb->sectors_per_cluster == 0 || (bpb->sectors_per_cluster & (bpb->sectors_per_cluster - 1)) != 0) {
        printf("DEBUG: Invalid sectors_per_cluster: %u (must be power of 2)\n", bpb->sectors_per_cluster);
        return -1;
    }

    // Nếu các thông số cơ bản có vẻ ổn, chúng ta tiến hành parse
    printf("DEBUG: BPB looks plausible. Bytes/Sec: %u, Sec/Clust: %u\n", bpb->bytes_per_sector, bpb->sectors_per_cluster);

    // Tính các địa chỉ quan trọng
    info->bytes_per_sector    = bpb->bytes_per_sector;
    info->sectors_per_cluster = bpb->sectors_per_cluster;
    info->bytes_per_cluster   = bpb->bytes_per_sector * bpb->sectors_per_cluster;

    info->fat_start_sector    = bpb->reserved_sectors;
    info->fat_size_sectors    = bpb->fat_size_32;

    // Data region bắt đầu sau Reserved + FAT1 + FAT2
    info->data_start_sector   = bpb->reserved_sectors
                                + (bpb->num_fats * bpb->fat_size_32);

    info->root_cluster        = bpb->root_cluster; // = 2
    info->total_clusters      = (bpb->total_sectors_32 - info->data_start_sector)
                                / bpb->sectors_per_cluster;

    printf("=== FAT32 Info ===\n");
    printf("Bytes/sector    : %u\n",   info->bytes_per_sector);
    printf("Sectors/cluster : %u\n",   info->sectors_per_cluster);
    printf("Bytes/cluster   : %u\n",   info->bytes_per_cluster);
    printf("FAT start       : sector %u\n", info->fat_start_sector);
    printf("Data start      : sector %u\n", info->data_start_sector);
    printf("Root cluster    : %u\n",   info->root_cluster);
    printf("Total clusters  : %u\n",   info->total_clusters);
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

    off_t offset = (off_t)info->fat_start_sector * info->bytes_per_sector;
    lseek(fd, offset, SEEK_SET);
    read(fd, fat, fatBytes);

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

// Tính sector đầu tiên của cluster N
uint32_t ClusterToSector(const FAT32_Info* info, uint32_t cluster) {
    // Cluster 2 = data_start_sector (cluster đánh số từ 2)
    return info->data_start_sector
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

// Kiểm tra entry có phải file đã bị xóa không
int IsDeletedFile(const FAT32_DirEntry* entry) {
    return entry->name[0] == 0xE5           // Dấu hiệu đã xóa
           && entry->attributes != ATTR_LFN    // Không phải LFN entry
           && !(entry->attributes & ATTR_DIRECTORY) // Không phải thư mục
           && entry->file_size > 0             // Có dữ liệu
           && GetFirstCluster(entry) >= 2;     // Cluster hợp lệ
}

// Build tên file từ entry (tên bị đánh dấu xóa, byte[0] = 0xE5)
void GetDeletedFileName(const FAT32_DirEntry* entry, char* out, size_t outSize) {
    char name[9] = {0};
    char ext[4]  = {0};

    // Byte 0 bị xóa thành 0xE5, thay bằng '_'
    name[0] = '_';
    for (int i = 1; i < 8; i++) {
        name[i] = (entry->name[i] == ' ') ? '\0' : entry->name[i];
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

// Đọc một cluster vào buffer
int ReadCluster(int fd, const FAT32_Info* info,
                uint32_t cluster, uint8_t* buffer) {
    uint32_t sector = ClusterToSector(info, cluster);
    off_t offset = (off_t)sector * info->bytes_per_sector;
    if (lseek(fd, offset, SEEK_SET) < 0) return -1;
    ssize_t n = read(fd, buffer, info->bytes_per_cluster);
    return (n == (ssize_t)info->bytes_per_cluster) ? 0 : -1;
}

// Forward declarations
void ScanDirectory(int fd, const FAT32_Info* info,
                   const uint32_t* fat,
                   uint32_t startCluster,
                   uint8_t* clusterBuf,
                   void* context,
                   FatFileCallback on_file,
                   const char* outputDir,
                   volatile int* cancelled,
                   int* recoveredCount);

// Scan một directory cluster — tìm entry có 0xE5
void ScanDirectoryCluster(int fd, const FAT32_Info* info,
                          const uint32_t* fat,
                          uint32_t cluster,
                          uint8_t* clusterBuf,
                          void* context,
                          FatFileCallback on_file,
                          const char* outputDir,
                          volatile int* cancelled,
                          int* recoveredCount) {
    uint32_t entriesPerCluster = info->bytes_per_cluster / sizeof(FAT32_DirEntry);
    FAT32_DirEntry* entries = (FAT32_DirEntry*)clusterBuf;

    for (uint32_t i = 0; i < entriesPerCluster; i++) {
        if (cancelled && *cancelled) return;
        FAT32_DirEntry* e = &entries[i];

        if (e->name[0] == 0x00) break; // Hết directory

        if (IsDeletedFile(e)) {
            char filename[64];
            GetDeletedFileName(e, filename, sizeof(filename));
            uint32_t first_cluster = GetFirstCluster(e);

            char outPath[512];
            snprintf(outPath, sizeof(outPath), "%s/fat_%04d_%s", outputDir, *recoveredCount, filename);

            // Recover file
            FILE* out = fopen(outPath, "wb");
            if (out) {
                uint8_t* fileBuf = (uint8_t*)malloc(info->bytes_per_cluster);
                uint32_t remaining = e->file_size;
                uint32_t curr = first_cluster;
                int useFATChain = !IsClusterFree(fat, curr);

                while (remaining > 0 && curr >= 2 && curr < 0x0FFFFFF8) {
                    if (ReadCluster(fd, info, curr, fileBuf) < 0) break;
                    uint32_t writeSize = (remaining < info->bytes_per_cluster) ? remaining : info->bytes_per_cluster;
                    fwrite(fileBuf, 1, writeSize, out);
                    remaining -= writeSize;

                    if (useFATChain) {
                        curr = FATNextCluster(fat, curr);
                    } else {
                        curr++;
                    }
                }
                fclose(out);
                free(fileBuf);

                if (on_file) {
                    on_file(context, "FAT", filename, (int64_t)e->file_size, (int64_t)ClusterToSector(info, first_cluster));
                }
                (*recoveredCount)++;
            }
        }

        // Nếu là thư mục còn sống → đi vào đệ quy
        if (e->name[0] != 0xE5
            && (e->attributes & ATTR_DIRECTORY)
            && !(e->attributes & ATTR_VOLUME_ID)
            && e->name[0] != '.') {
            uint32_t subCluster = GetFirstCluster(e);
            // Cần buffer riêng cho đệ quy để không ghi đè buffer hiện tại
            uint8_t* subBuf = (uint8_t*)malloc(info->bytes_per_cluster);
            ScanDirectory(fd, info, fat, subCluster, subBuf, context, on_file, outputDir, cancelled, recoveredCount);
            free(subBuf);
        }
    }
}

// Scan toàn bộ directory (follow cluster chain)
void ScanDirectory(int fd, const FAT32_Info* info,
                   const uint32_t* fat,
                   uint32_t startCluster,
                   uint8_t* clusterBuf,
                   void* context,
                   FatFileCallback on_file,
                   const char* outputDir,
                   volatile int* cancelled,
                   int* recoveredCount) {
    uint32_t cluster = startCluster;
    int maxChain = 65536; // Giới hạn phòng loop vô hạn

    while (cluster >= 2 && cluster < 0x0FFFFFF8 && maxChain-- > 0) {
        if (cancelled && *cancelled) return;
        if (ReadCluster(fd, info, cluster, clusterBuf) == 0) {
            ScanDirectoryCluster(fd, info, fat, cluster,
                                 clusterBuf, context, on_file, outputDir, cancelled, recoveredCount);
        }
        cluster = FATNextCluster(fat, cluster);
    }
}

int RecoverAllDeletedFiles(int fd, const uint8_t* sector0,
                           const char* outputDir, void* context, FatFileCallback on_file, volatile int* cancelled) {
    // 1. Parse BPB
    FAT32_BPB bpb;
    FAT32_Info info;
    if (ParseBPB(sector0, &bpb, &info) < 0) return 0;

    // 2. Load FAT table
    uint32_t* fat = LoadFATTable(fd, &info);
    if (!fat) return 0;

    // 3. Alloc cluster buffer
    uint8_t* clusterBuf = (uint8_t*)malloc(info.bytes_per_cluster);

    mkdir(outputDir, 0755);

    int recoveredCount = 0;
    // 5. Bắt đầu scan từ root directory (cluster 2)
    printf("=== Bắt đầu scan FAT32 từ root cluster %u ===\n", info.root_cluster);
    ScanDirectory(fd, &info, fat, info.root_cluster,
                  clusterBuf, context, on_file, outputDir, cancelled, &recoveredCount);

    printf("\n=== Tổng cộng tìm thấy FAT32: %d file ===\n", recoveredCount);

    free(clusterBuf);
    free(fat);
    return recoveredCount;
}
