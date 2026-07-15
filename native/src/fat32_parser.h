#pragma once
#include <stdint.h>

// Forward declaration của RecoveryCallback từ recovery_ffi.h (tránh include vòng)
typedef void (*FatFileCallback)(void* ctx, const char* type, const char* name, const char* modifiedTime, int64_t size, int64_t sector, int64_t sector_count);
typedef void (*FatProgressCallback)(void* ctx, double pct, int64_t scanned, int32_t speed);

int RecoverAllFiles(int fd, int64_t baseSector, const uint8_t* sector0, const char* outputDir, void* context, FatFileCallback on_file, FatProgressCallback on_progress, volatile int* cancelled, int scan_mode);
