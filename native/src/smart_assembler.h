#pragma once
#include <stdint.h>
#include "recovery_ffi.h"
#include "fat32_parser.h"

typedef void (*AssembleFileCallback)(void* context, FileInfo* info, const char* outPath);

int ProcessFiles(int fd, int64_t baseSector, FileCollector* collector, const char* outputDir, void* context, FatFileCallback on_file, FatProgressCallback on_progress, volatile int* cancelled, uint8_t* sector_mask, int64_t total_sectors);
