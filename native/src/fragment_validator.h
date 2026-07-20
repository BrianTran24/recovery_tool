#pragma once
#include <stdint.h>
#include <stddef.h>

typedef struct {
    int log2_max_frame_num;
    int width;
    int height;
    int profile_idc;
} H264Context;

typedef struct {
    uint8_t dqt_ids[4];
    int has_restart_markers;
    int restart_interval;
} JPEGContext;

// Calculate Shannon Entropy
double calculate_entropy_fv(const uint8_t* data, size_t len);

// Validate if a block of data (cluster) belongs to the current H.264 stream
int validate_h264_fragment(const H264Context* ctx, const uint8_t* buf, size_t len, int* last_frame_num);

// Validate if a block of data belongs to the current JPEG stream
int validate_jpeg_fragment(const JPEGContext* ctx, const uint8_t* buf, size_t len);

// Extract H264Context from SPS NAL unit
int parse_h264_sps(const uint8_t* sps, size_t len, H264Context* out);

// Extract JPEGContext from JPEG header
int parse_jpeg_header_info(const uint8_t* buf, size_t len, JPEGContext* out);
