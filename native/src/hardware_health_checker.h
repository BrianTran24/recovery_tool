#pragma once
#include <stdint.h>
#include "shared_types.h"

#define HW_HEALTH_OK               0
#define HW_HEALTH_ZERO_CAPACITY    1
#define HW_HEALTH_IO_ERROR         2
#define HW_HEALTH_CONTROLLER_ERROR 3

int32_t check_hardware_health(int32_t handle, HardwareHealthInfo* info);
