#pragma once
#include <stdint.h>

#define HW_HEALTH_OK               0
#define HW_HEALTH_ZERO_CAPACITY    1
#define HW_HEALTH_IO_ERROR         2
#define HW_HEALTH_CONTROLLER_ERROR 3

typedef struct {
    int32_t status;
    int64_t capacity;
    char    controller_id[64];
    char    firmware_version[32];
    char    error_message[256];
} HardwareHealthInfo;

int32_t check_hardware_health(int32_t handle, HardwareHealthInfo* info);
