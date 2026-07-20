#include "hardware_health_checker.h"
#include "sector_reader.h"
#include <string.h>
#include <stdio.h>

int32_t check_hardware_health(int32_t handle, HardwareHealthInfo* info) {
    if (handle < 0 || info == NULL) return HW_HEALTH_IO_ERROR;

    memset(info, 0, sizeof(HardwareHealthInfo));

    DiskGeometry geo;
    if (GetDiskGeometry(handle, &geo) != 0) {
        info->status = HW_HEALTH_CONTROLLER_ERROR;
        snprintf(info->error_message, sizeof(info->error_message), "Could not read disk geometry. Controller might be unresponsive.");
        return info->status;
    }

    info->capacity = geo.totalBytes;

    // Simulating controller info (In real scenarios, this would involve IOCTLs or SCSI Passthrough)
    snprintf(info->controller_id, sizeof(info->controller_id), "FL-CONTROLLER-001");
    snprintf(info->firmware_version, sizeof(info->firmware_version), "v1.0.4");

    if (info->capacity <= 0) {
        info->status = HW_HEALTH_ZERO_CAPACITY;
        snprintf(info->error_message, sizeof(info->error_message), "Device reports 0MB capacity. FTL might be corrupted.");
        return info->status;
    }

    // Sanity read test: Read first sector
    uint8_t buffer[512];
    size_t bytesRead = 0;
    if (ReadSectors(handle, 0, 1, 512, buffer, &bytesRead) != 0 || bytesRead < 512) {
        info->status = HW_HEALTH_IO_ERROR;
        snprintf(info->error_message, sizeof(info->error_message), "Failed to read first sector (MBR/VBR). Physical I/O error.");
        return info->status;
    }

    // Check if sector is suspiciously empty (all 00 or FF) - common in FTL failure
    int all_zero = 1;
    int all_ff = 1;
    for (int i = 0; i < 512; i++) {
        if (buffer[i] != 0x00) all_zero = 0;
        if (buffer[i] != 0xFF) all_ff = 0;
        if (!all_zero && !all_ff) break;
    }

    if (all_zero || all_ff) {
        // This is a warning sign, but not always a failure (e.g., zero-filled drive)
        // However, if capacity is missing or partition table is expected, it's a hint.
    }

    info->status = HW_HEALTH_OK;
    snprintf(info->error_message, sizeof(info->error_message), "Hardware health check passed.");
    return info->status;
}
