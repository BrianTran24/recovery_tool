#pragma once
#include <stdint.h>
#include <stddef.h>

// Device IDs
#define DEVICE_NONE   0
#define DEVICE_GOPRO  1
#define DEVICE_DJI    2

int is_gopro_device(const uint8_t* buf, size_t len);
int is_dji_device(const uint8_t* buf, size_t len);

int handle_device_carve(int fd, uint64_t start_byte, uint64_t max_size, const char* output_path, int device_id, uint64_t* out_written);
