#pragma once
#include <stdint.h>

/**
 * Repairs a broken MP4/MOV file using a healthy reference file.
 * @param brokenPath Path to the recovered file with missing/corrupted moov atom.
 * @param referencePath Path to a healthy file from the same device/settings.
 * @param outputPath Path where the repaired file will be saved.
 * @return 0 on success, negative error code on failure.
 */
int RepairVideo(const char* brokenPath, const char* referencePath, const char* outputPath);
