// carver.h
#pragma once
#include <stdint.h>
#include <stddef.h>

#define MAX_HEADER_LEN  16
#define MAX_FOOTER_LEN  16
#define MAX_FILE_SIZE   (500ULL * 1024 * 1024)
#define MIN_FILE_SIZE   (1024 * 1024) // Filter out files smaller than 1MB

// Guided Carving utilities
double calculate_entropy(const uint8_t* data, size_t len);
int is_cluster_header(const uint8_t* buf, size_t len);

typedef void (*CarveProgressCallback)(void* context, double pct, int64_t scanned, int32_t speed);
typedef void (*CarveFileCallback)(void* context, const char* type, const char* name, const char* modifiedTime, int64_t size, int64_t sector);

int CarveFilesWithProgress(
    int fd,
    uint64_t disk_size,
    uint32_t sector_size,
    const char* output_dir,
    void* context,
    CarveProgressCallback on_progress,
    CarveFileCallback on_file,
    volatile int* cancelled,
    double progress_start,
    double progress_end,
    const uint8_t* used_mask,
    const char* reference_video
);

int ExtractFileRange(int fd, uint64_t start_byte, uint64_t file_size, const char* output_path);
