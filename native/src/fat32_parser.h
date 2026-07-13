#pragma once
#include <stdint.h>

// Forward declaration của RecoveryCallback từ recovery_ffi.h (tránh include vòng)
typedef void (*FatFileCallback)(void* ctx, const char* type, const char* name, int64_t size, int64_t sector);
typedef void (*FatProgressCallback)(void* ctx, double pct, int64_t scanned, int32_t speed);

int RecoverAllDeletedFiles(int fd, const uint8_t* sector0, const char* outputDir, void* context, FatFileCallback on_file, FatProgressCallback on_progress, volatile int* cancelled);
