#pragma once
#include <stdint.h>

#pragma pack(push, 1)
typedef struct {
    int32_t status;
    int64_t capacity;
    char    controller_id[64];
    char    firmware_version[32];
    char    error_message[256];
} HardwareHealthInfo;
#pragma pack(pop)
