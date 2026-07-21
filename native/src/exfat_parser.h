#pragma once

#include <stdint.h>
#include <stddef.h>

#include "fat32_parser.h"

int RecoverExfatAllFiles(
    int fd,
    int64_t baseSector,
    const uint8_t* bootSector,
    size_t bootSectorLen,
    const char* outputDir,
    void* context,
    FatFileCallback on_file,
    FatProgressCallback on_progress,
    volatile int* cancelled,
    volatile int* paused,
    int scan_mode
);

void CollectHealthyFilesExfat(int fd, int64_t baseSector, const uint8_t* sector0, FileCollector* collector, void* context, FatProgressCallback on_progress, volatile int* cancelled, volatile int* paused, int scan_mode);
void ScanOrphanedEntriesExfat(int fd, int64_t baseSector, const uint8_t* sector0, FileCollector* collector, void* context, FatProgressCallback on_progress, volatile int* cancelled, volatile int* paused);
