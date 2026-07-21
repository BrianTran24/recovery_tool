#pragma once
#include <stdint.h>
#include "recovery_ffi.h"

// Forward declaration của RecoveryCallback từ recovery_ffi.h (tránh include vòng)
typedef void (*FatFileCallback)(void* ctx, const char* type, const char* name, const char* modifiedTime, int64_t size, int64_t sector, int64_t sector_count, const char* folder);
typedef void (*FatProgressCallback)(void* ctx, double pct, int64_t scanned, int32_t speed);

// New unified collector type
typedef struct {
    FileInfo* files;
    uint32_t count;
    uint32_t capacity;
} FileCollector;

int RecoverAllFiles(int fd, int64_t baseSector, const uint8_t* sector0, const char* outputDir, void* context, FatFileCallback on_file, FatProgressCallback on_progress, volatile int* cancelled, volatile int* paused, int scan_mode);

// Modules
void CollectHealthyFilesFat32(int fd, int64_t baseSector, const uint8_t* sector0, FileCollector* collector, void* context, FatProgressCallback on_progress, volatile int* cancelled, volatile int* paused, int scan_mode);
void ScanOrphanedEntriesFat32(int fd, int64_t baseSector, const uint8_t* sector0, FileCollector* collector, void* context, FatProgressCallback on_progress, volatile int* cancelled, volatile int* paused);
