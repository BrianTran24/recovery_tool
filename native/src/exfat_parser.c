#include "exfat_parser.h"
#include "platform_config.h"
#include "carver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define EXFAT_ENTRY_FILE   0x85
#define EXFAT_ENTRY_STREAM 0xC0
#define EXFAT_ENTRY_NAME   0xC1
#define EXFAT_ATTR_DIRECTORY 0x10

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
    if (len >= 3 && isalpha(tmp[0]) && tmp[1] == ':' && tmp[2] == PATH_SEP) p = tmp + 3;
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

typedef struct {
    int64_t  baseSector;
    uint32_t fatOffset;
    uint32_t fatLength;
    uint32_t volumeFlags;
    uint8_t  numberOfFats;
    uint32_t clusterHeapOffset;
    uint32_t clusterCount;
    uint32_t rootCluster;
    uint8_t  bytesPerSectorShift;
    uint8_t  sectors_per_cluster_shift;
} ExfatBootInfo;

static uint32_t ReadLe32(const uint8_t* p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static uint64_t ReadLe64(const uint8_t* p) {
    return (uint64_t)ReadLe32(p) | ((uint64_t)ReadLe32(p + 4) << 32);
}

static uint32_t ClusterSizeBytes(const ExfatBootInfo* info) {
    return (uint32_t)(1ULL << (info->bytesPerSectorShift + info->sectors_per_cluster_shift));
}

static uint32_t ClusterSizeSectors(const ExfatBootInfo* info) {
    return (uint32_t)(1ULL << info->sectors_per_cluster_shift);
}

static int ReadCluster(int fd, const ExfatBootInfo* info, uint32_t cluster, uint8_t* buf) {
    if (cluster < 2 || cluster > info->clusterCount + 1) return -1;
    int64_t sector = (int64_t)info->baseSector + info->clusterHeapOffset + (int64_t)(cluster - 2) * ClusterSizeSectors(info);
    if (LSEEK(fd, sector * 512, SEEK_SET) < 0) return -1;
    uint32_t clusSz = ClusterSizeBytes(info);
    return (READ(fd, buf, clusSz) == (ssize_t)clusSz) ? 0 : -1;
}

static uint8_t* LoadExfatFat(int fd, const ExfatBootInfo* info, size_t* outSize) {
    uint32_t fatSz = info->fatLength * 512;
    uint8_t* fat = (uint8_t*)malloc(fatSz);
    if (!fat) return NULL;
    LSEEK(fd, (int64_t)(info->baseSector + info->fatOffset) * 512, SEEK_SET);
    if (READ(fd, fat, fatSz) != (ssize_t)fatSz) { free(fat); return NULL; }
    if (outSize) *outSize = fatSz;
    return fat;
}

static uint32_t ExfatFatNextCluster(const uint8_t* fat, uint32_t cluster) {
    return ReadLe32(fat + (cluster * 4)) & 0x0FFFFFFF;
}

static int ExfatIsEoc(uint32_t cluster) {
    return cluster >= 0x0FFFFFF8;
}

static int ExfatClusterValid(const ExfatBootInfo* info, uint32_t cluster) {
    return cluster >= 2 && cluster <= info->clusterCount + 1;
}

#define EXFAT_MAX_DIR_DEPTH 100

static void FormatExfatTimestamp(uint32_t raw, char* out, size_t outSize) {
    uint16_t timePart = (uint16_t)(raw & 0xFFFFU);
    uint16_t datePart = (uint16_t)((raw >> 16) & 0xFFFFU);
    uint32_t year = (uint32_t)((datePart >> 9) & 0x7FU) + 1980U;
    uint32_t month = (uint32_t)((datePart >> 5) & 0x0FU);
    uint32_t day = (uint32_t)(datePart & 0x1FU);
    uint32_t hour = (uint32_t)((timePart >> 11) & 0x1FU);
    uint32_t minute = (uint32_t)((timePart >> 5) & 0x3FU);
    uint32_t second = (uint32_t)(timePart & 0x1FU) * 2U;
    if (year < 1980U || month == 0U || month > 12U || day == 0U || day > 31U) { if (outSize > 0) out[0] = '\0'; return; }
    snprintf(out, outSize, "%04u-%02u-%02u %02u:%02u:%02u", year, month, day, hour, minute, second);
}

static uint16_t EntrySetChecksum(const uint8_t* entries, uint8_t secondaryCount) {
    uint16_t checksum = 0;
    uint16_t numberOfBytes = (uint16_t)(secondaryCount + 1U) * 32U;
    for (uint16_t i = 0; i < numberOfBytes; i++) {
        if (i == 2 || i == 3) continue;
        checksum = (uint16_t)(((checksum & 1U) ? 0x8000U : 0U) + (checksum >> 1) + entries[i]);
    }
    return checksum;
}

static void DecodeExfatName(const uint8_t* entries, uint8_t secondaryCount, uint8_t nameLength, char* out, size_t outSize) {
    size_t written = 0;
    uint8_t remaining = nameLength;
    for (uint8_t i = 0; i + 1 < secondaryCount && remaining > 0; i++) {
        const uint8_t* e = entries + (2 + i) * 32;
        if ((e[0] & 0x7F) != 0x41) continue;
        for (int k = 0; k < 15 && remaining > 0; k++) {
            uint16_t ch = e[2 + k * 2] | (e[3 + k * 2] << 8);
            if (ch == 0) break;
            if (written < outSize - 1) out[written++] = (ch < 128) ? (char)ch : '?';
            remaining--;
        }
    }
    out[written] = 0;
}

static int ParseExfatEntrySet(const uint8_t* set, uint8_t secondaryCount, char* nameOut, size_t nameOutSize, char* modifiedTimeOut, size_t modifiedTimeOutSize, uint32_t* firstClusterOut, uint64_t* dataLengthOut, uint8_t* flagsOut, uint16_t* checksumOut, int* isChecksumValidOut) {
    const uint8_t* primary = set;
    const uint8_t* stream = set + 32;
    if ((primary[0] & 0x7F) != 0x05 || (stream[0] & 0x7F) != 0x40) return 0;
    uint8_t nameLength = stream[3];
    uint8_t flags = stream[1];
    uint32_t firstClus = ReadLe32(stream + 20);
    uint64_t dataLen = ReadLe64(stream + 24);
    uint32_t modifiedRaw = ReadLe32(primary + 12);
    uint16_t storedChecksum = (uint16_t)primary[2] | ((uint16_t)primary[3] << 8);
    uint16_t computedChecksum = EntrySetChecksum(set, secondaryCount);
    if (checksumOut) *checksumOut = storedChecksum;
    if (isChecksumValidOut) *isChecksumValidOut = (storedChecksum == computedChecksum);
    if (flagsOut) *flagsOut = flags;
    if (firstClusterOut) *firstClusterOut = firstClus;
    if (dataLengthOut) *dataLengthOut = dataLen;
    if (nameOut) DecodeExfatName(set, secondaryCount, nameLength, nameOut, nameOutSize);
    if (modifiedTimeOut) FormatExfatTimestamp(modifiedRaw, modifiedTimeOut, modifiedTimeOutSize);
    return 1;
}

static uint8_t* LoadClusterChainBuffer(int fd, const ExfatBootInfo* info, const uint8_t* fat, uint32_t startCluster, int useFatChain, size_t* outLen) {
    uint32_t clusSz = ClusterSizeBytes(info);
    size_t cap = clusSz * 8;
    uint8_t* out = (uint8_t*)malloc(cap);
    uint8_t* tmp = (uint8_t*)malloc(clusSz);
    if (!out || !tmp) { free(out); free(tmp); return NULL; }
    size_t len = 0;
    uint32_t cur = startCluster;
    int maxChain = 65536;
    while (cur >= 2 && cur <= info->clusterCount + 1 && maxChain-- > 0) {
        if (ReadCluster(fd, info, cur, tmp) != 0) break;
        if (len + clusSz > cap) {
            cap *= 2;
            uint8_t* grown = (uint8_t*)realloc(out, cap);
            if (!grown) break;
            out = grown;
        }
        memcpy(out + len, tmp, clusSz);
        len += clusSz;
        if (useFatChain && fat) cur = ExfatFatNextCluster(fat, cur);
        else cur++;
        if (ExfatIsEoc(cur)) break;
    }
    free(tmp);
    if (outLen) *outLen = len;
    return out;
}

static uint8_t* LoadAllocationBitmapFromRoot(int fd, const ExfatBootInfo* info, const uint8_t* fat, const uint8_t* rootBuf, size_t rootLen, size_t* outBytes) {
    for (size_t off = 0; off + 32 <= rootLen; off += 32) {
        if ((rootBuf[off] & 0x7F) == 0x01) {
            uint32_t first = ReadLe32(rootBuf + off + 20);
            uint64_t sz = ReadLe64(rootBuf + off + 24);
            size_t actual = 0;
            uint8_t* bmp = LoadClusterChainBuffer(fd, info, fat, first, 1, &actual);
            if (outBytes) *outBytes = actual;
            return bmp;
        }
    }
    return NULL;
}

// Bitmap "visited" theo cluster thư mục đã duyệt — chống đệ quy vô hạn (vòng lặp,
// cross-link) và chống thu thập trùng lặp giữa pha cây thư mục và pha sweep.
static inline int ExfatVisitedTest(const uint8_t* v, uint32_t c) {
    return v ? (v[c >> 3] & (1 << (c & 7))) : 0;
}
static inline void ExfatVisitedSet(uint8_t* v, uint32_t c) {
    if (v) v[c >> 3] |= (uint8_t)(1 << (c & 7));
}

static int IsExfatDirCluster(const uint8_t* buf, uint32_t sz) {
    int count = 0;
    for (uint32_t off = 0; off + 32 <= sz; off += 32) {
        if (buf[off] == 0x85 || buf[off] == 0xC0 || buf[off] == 0xC1) count++;
    }
    return count >= 2;
}

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

// Validate a File entry set at offset `off` within a directory cluster buffer.
// Rejects corrupt/garbage data: sane secondary count, the whole set must fit inside
// the cluster buffer, a valid Stream extension must follow, and the set checksum must match.
static int ValidExfatEntrySet(const uint8_t* buf, uint32_t clusSz, uint32_t off, uint8_t sc, int strict) {
    if (sc < 2 || sc > 18) return 0;
    uint32_t setBytes = (uint32_t)(sc + 1) * 32;
    if ((uint64_t)off + setBytes > clusSz) return 0;
    if ((buf[off + 32] & 0x7F) != 0x40) return 0;
    // Chỉ ép khớp checksum ở chế độ strict (dùng cho quét mù toàn ổ để tránh rác).
    // Khi duyệt cây thư mục hợp lệ (strict=0) ta khoan dung với checksum lệch để vẫn
    // cứu được tên/size của entry hư nhẹ — giống DMDE.
    if (strict) {
        uint16_t stored = (uint16_t)buf[off + 2] | ((uint16_t)buf[off + 3] << 8);
        if (EntrySetChecksum(buf + off, sc) != stored) return 0;
    }
    return 1;
}

static void PopulateExfatFileInfo(FileInfo* fi, const ExfatBootInfo* info, const uint8_t* fat, const uint8_t* buf, uint32_t off, const char* relPath, int status) {    uint8_t sc = buf[off + 1];
    char name[256] = {0}, mod[32] = {0};
    uint32_t first = 0; uint64_t len = 0; uint8_t flg = 0; uint16_t chk = 0; int chkOk = 0;
    if (!ParseExfatEntrySet(buf + off, sc, name, 256, mod, 32, &first, &len, &flg, &chk, &chkOk)) return;
    memset(fi, 0, sizeof(FileInfo));
    fi->starting_cluster = first;
    if (name[0] != '\0') snprintf(fi->filename, sizeof(fi->filename), "%s", name);
    if (fi->filename[0] == '\0') snprintf(fi->filename, sizeof(fi->filename), "FILE_%u", fi->starting_cluster);
    if (relPath) snprintf(fi->rel_path, sizeof(fi->rel_path), "%s", relPath);
    snprintf(fi->modified_time, sizeof(fi->modified_time), "%s", mod);
    fi->file_size = (int64_t)len;
    fi->status = status;
    fi->is_deleted = ((buf[off] & 0x80) == 0);
    if (!fi->is_deleted && len > 0 && ExfatClusterValid(info, first)) {
        uint32_t clusSz = ClusterSizeBytes(info);
        uint32_t clusCount = (uint32_t)((len + clusSz - 1) / clusSz);
        if (clusCount > info->clusterCount) clusCount = info->clusterCount;
        if (clusCount > 0) {
            fi->cluster_chain = (uint32_t*)malloc((size_t)clusCount * sizeof(uint32_t));
            if (fi->cluster_chain) {
                uint32_t j = 0;
                if (flg & 0x02) {
                    // NoFatChain: allocation is contiguous — clusters are sequential.
                    // Xây chain tường minh để dùng AssembleHealthy (đọc thẳng), tránh
                    // heuristic chống phân mảnh của AssembleSmart vốn làm hỏng/không
                    // xuất được nhiều file liền mạch (JPG/MP4 GoPro).
                    for (; j < clusCount; j++) {
                        uint32_t c = first + j;
                        if (!ExfatClusterValid(info, c)) break;
                        fi->cluster_chain[j] = c;
                    }
                } else if (fat) {
                    uint32_t cur = first;
                    for (; j < clusCount; j++) {
                        if (!ExfatClusterValid(info, cur)) break;
                        fi->cluster_chain[j] = cur;
                        cur = ExfatFatNextCluster(fat, cur);
                        if (ExfatIsEoc(cur)) { j++; break; }
                    }
                }
                fi->chain_length = j;
                if (j == 0) { free(fi->cluster_chain); fi->cluster_chain = NULL; }
            }
        }
    }
}

static void CollectFromExfatDir(int fd, const ExfatBootInfo* info, const uint8_t* fat, const uint8_t* bitmap, size_t bitmapBytes, uint32_t startCluster, FileCollector* collector, const char* relPath, volatile int* cancelled, int scan_mode, int useFatChain, int depth, uint8_t* visited);

static void CollectFromExfatCluster(int fd, const ExfatBootInfo* info, const uint8_t* fat, const uint8_t* bitmap, size_t bitmapBytes, const uint8_t* buf, FileCollector* collector, const char* relPath, volatile int* cancelled, int scan_mode, int depth, uint8_t* visited, int strict) {
    uint32_t clusSz = ClusterSizeBytes(info);
    for (uint32_t off = 0; off + 32 <= clusSz; off += 32) {
        if (cancelled && *cancelled) return;
        if ((buf[off] & 0x7F) == 0x05) {
            uint8_t sc = buf[off + 1];
            if (!ValidExfatEntrySet(buf, clusSz, off, sc, strict)) continue;
            uint16_t attr = buf[off + 4] | (buf[off + 5] << 8);
            int isDel = ((buf[off] & 0x80) == 0);
            if ((scan_mode == 1 && !isDel) || (scan_mode == 2 && isDel)) { off += (uint32_t)sc * 32; continue; }
            FileInfo fi;
            PopulateExfatFileInfo(&fi, info, fat, buf, off, relPath, FILE_STATUS_HEALTHY);
            if (attr & EXFAT_ATTR_DIRECTORY) {
                // DCIM và các thư mục khác là THƯ MỤC, không phải file: KHÔNG thu thập
                // entry thư mục như một file (nếu không, khi xuất ra đĩa nó bị ghi thành
                // một khối nhị phân theo dataLength của thư mục — có thể rác/khổng lồ như
                // 20GB — "mở không được"). Chỉ đệ quy để thu thập file/thư mục con bên
                // trong; cấu trúc cây được tái tạo qua rel_path khi ghi ra đĩa.
                uint8_t streamFlags = buf[off + 32 + 1];
                uint32_t first = ReadLe32(buf + off + 32 + 20);
                if (depth < EXFAT_MAX_DIR_DEPTH && ExfatClusterValid(info, first)) {
                    char subRel[512];
                    if (relPath && relPath[0]) snprintf(subRel, 512, "%s%c%s", relPath, PATH_SEP, fi.filename);
                    else snprintf(subRel, 512, "%s", fi.filename);
                    CollectFromExfatDir(fd, info, fat, bitmap, bitmapBytes, first, collector, subRel, cancelled, scan_mode, !(streamFlags & 0x02), depth + 1, visited);
                }
                if (fi.cluster_chain) { free(fi.cluster_chain); fi.cluster_chain = NULL; }
            } else if (fi.filename[0]) {
                AddToFileCollector(collector, &fi);
            }
            off += (uint32_t)sc * 32;
        }
    }
}

static void CollectFromExfatDir(int fd, const ExfatBootInfo* info, const uint8_t* fat, const uint8_t* bitmap, size_t bitmapBytes, uint32_t startCluster, FileCollector* collector, const char* relPath, volatile int* cancelled, int scan_mode, int useFatChain, int depth, uint8_t* visited) {
    if (depth > EXFAT_MAX_DIR_DEPTH) return;
    uint32_t cur = startCluster, clusSz = ClusterSizeBytes(info);
    uint8_t* buf = (uint8_t*)malloc(clusSz);
    if (!buf) return;
    int limit = 10000;
    while (cur >= 2 && cur <= info->clusterCount + 1 && limit-- > 0) {
        if (cancelled && *cancelled) break;
        // Chống vòng lặp/cross-link + thu thập trùng: dừng nếu cluster thư mục đã duyệt.
        if (visited) {
            if (ExfatVisitedTest(visited, cur)) break;
            ExfatVisitedSet(visited, cur);
        }
        if (ReadCluster(fd, info, cur, buf) == 0) CollectFromExfatCluster(fd, info, fat, bitmap, bitmapBytes, buf, collector, relPath, cancelled, scan_mode, depth, visited, 0);
        if (useFatChain && fat) cur = ExfatFatNextCluster(fat, cur); else cur++;
        if (ExfatIsEoc(cur)) break;
    }
    free(buf);
}

static int ParseExfatBoot(const uint8_t* sector0, ExfatBootInfo* info) {
    if (memcmp(sector0 + 3, "EXFAT   ", 8) != 0) return -1;
    info->fatOffset = ReadLe32(sector0 + 80);
    info->fatLength = ReadLe32(sector0 + 84);
    info->volumeFlags = (uint32_t)sector0[106] | ((uint32_t)sector0[107] << 8);
    info->numberOfFats = sector0[110];
    info->clusterHeapOffset = ReadLe32(sector0 + 88);
    info->clusterCount = ReadLe32(sector0 + 92);
    info->rootCluster = ReadLe32(sector0 + 96);
    info->bytesPerSectorShift = sector0[108];
    info->sectors_per_cluster_shift = sector0[109];
    return 0;
}

void CollectHealthyFilesExfat(int fd, int64_t baseSector, const uint8_t* sector0, FileCollector* collector, void* context, FatProgressCallback on_progress, volatile int* cancelled, int scan_mode) {
    ExfatBootInfo info; info.baseSector = baseSector;
    if (ParseExfatBoot(sector0, &info) < 0) return;
    size_t fatSz = 0; uint8_t* fat = LoadExfatFat(fd, &info, &fatSz);
    size_t rootLen = 0; uint8_t* rootBuf = LoadClusterChainBuffer(fd, &info, fat, info.rootCluster, 1, &rootLen);
    size_t bmpSz = 0; uint8_t* bmp = rootBuf ? LoadAllocationBitmapFromRoot(fd, &info, fat, rootBuf, rootLen, &bmpSz) : NULL;

    // Bitmap visited để chống vòng lặp thư mục và thu thập trùng
    uint8_t* visited = (uint8_t*)calloc(((size_t)info.clusterCount + 2) / 8 + 1, 1);

    // Duyệt cây thư mục từ Root.
    CollectFromExfatDir(fd, &info, fat, bmp, bmpSz, info.rootCluster, collector, "", cancelled, scan_mode, 1, 0, visited);

    if (visited) free(visited);
    if (fat) free(fat); if (bmp) free(bmp); if (rootBuf) free(rootBuf);
}

void ScanOrphanedEntriesExfat(int fd, int64_t baseSector, const uint8_t* sector0, FileCollector* collector, void* context, FatProgressCallback on_progress, volatile int* cancelled) {
    ExfatBootInfo info; info.baseSector = baseSector;
    if (ParseExfatBoot(sector0, &info) < 0) return;
    size_t fatSz = 0; uint8_t* fat = LoadExfatFat(fd, &info, &fatSz);
    uint32_t clusSz = ClusterSizeBytes(&info); uint8_t* clusBuf = (uint8_t*)malloc(clusSz);

    // Bitmap visited để tránh quét lại các cluster đã xử lý trong cùng pha sweep này
    uint8_t* visited = (uint8_t*)calloc(((size_t)info.clusterCount + 2) / 8 + 1, 1);

    uint32_t last_progress_c = 2;
    int64_t last_progress_ms = GetTimeMs();

    if (clusBuf && visited) {
        for (uint32_t c = 2; c <= info.clusterCount + 1 && (!cancelled || !*cancelled); c++) {
            if (ExfatVisitedTest(visited, c)) continue;

            if (ReadCluster(fd, &info, c, clusBuf) == 0) {
                // 1. Kiểm tra xem có phải cụm chứa thư mục (Lost Directory)
                if (IsExfatDirCluster(clusBuf, clusSz)) {
                    char fld[64]; snprintf(fld, 64, "LostDir_%u", c);
                    CollectFromExfatCluster(fd, &info, fat, NULL, 0, clusBuf, collector, fld, cancelled, SCAN_MODE_BOTH, 0, visited, 1);
                } else {
                    // 2. Quét từng entry lẻ (Orphaned Files)
                    for (uint32_t off = 0; off + 32 <= clusSz; off += 32) {
                        if ((clusBuf[off] & 0x7F) == 0x05) {
                            uint8_t sc = clusBuf[off + 1];
                            if (!ValidExfatEntrySet(clusBuf, clusSz, off, sc, 1)) continue;
                            uint16_t attr = clusBuf[off + 4] | (clusBuf[off + 5] << 8);
                            if (attr & EXFAT_ATTR_DIRECTORY) { off += (uint32_t)sc * 32; continue; }

                            FileInfo fi; PopulateExfatFileInfo(&fi, &info, fat, clusBuf, off, "ORPHANED", FILE_STATUS_ORPHANED);
                            if (fi.filename[0]) AddToFileCollector(collector, &fi);
                            off += (uint32_t)sc * 32;
                        }
                    }
                }
            }
            if (on_progress && (c % 10000 == 0)) {
                int64_t now = GetTimeMs();
                int32_t speed = 0;
                if (now > last_progress_ms) {
                    uint64_t processed = (uint64_t)(c - last_progress_c) * clusSz;
                    speed = (int32_t)((double)processed * 1000.0 / (double)(now - last_progress_ms) / (1024.0 * 1024.0));
                }
                on_progress(context, ((double)c / info.clusterCount) * 100.0, (int64_t)c * clusSz, speed);
                last_progress_c = c;
                last_progress_ms = now;
            }
        }
    }
    if (clusBuf) free(clusBuf);
    if (visited) free(visited);
    if (fat) free(fat);
}

int RecoverExfatAllFiles(int fd, int64_t baseSector, const uint8_t* sector0, size_t bootSectorLen, const char* outputDir, void* context, FatFileCallback on_file, FatProgressCallback on_progress, volatile int* cancelled, int scan_mode) {
    return 0; // Legacy function not used in the new 4-module architecture
}
