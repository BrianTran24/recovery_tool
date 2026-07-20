#include "fragment_validator.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

void test_entropy() {
    uint8_t random_data[256];
    for(int i=0; i<256; i++) random_data[i] = i;
    double e = calculate_entropy_fv(random_data, 256);
    printf("Entropy of 0..255: %f\n", e);
    assert(e > 7.9);
}

void test_h264_sps() {
    // A real SPS from a GoPro (simplified header)
    uint8_t sps[] = {
        0x00, 0x00, 0x00, 0x01, 0x67, // NAL Header
        0x64, 0x00, 0x28, // Profile High, Level 4.0
        0xAC, 0xD9, 0x40, 0x78, 0x02, 0x27, 0xE5, 0x84, 0x00, 0x00, 0x03, 0x00, 0x04, 0x00, 0x00, 0x03, 0x00, 0xF0, 0x3C, 0x60, 0xC9, 0x20
    };
    H264Context ctx;
    int res = parse_h264_sps(sps + 4, sizeof(sps) - 4, &ctx);
    printf("SPS parse result: %d, profile: %d, log2_max_frame_num: %d\n", res, ctx.profile_idc, ctx.log2_max_frame_num);
    assert(res == 1);
    assert(ctx.profile_idc == 100);
}

void test_jpeg_header() {
    uint8_t jpeg[] = {
        0xFF, 0xD8, // SOI
        0xFF, 0xDD, 0x00, 0x04, 0x00, 0x0A, // DRI (Restart interval 10)
        0xFF, 0xDA // SOS
    };
    JPEGContext ctx;
    parse_jpeg_header_info(jpeg, sizeof(jpeg), &ctx);
    printf("JPEG restart markers: %d, interval: %d\n", ctx.has_restart_markers, ctx.restart_interval);
    assert(ctx.has_restart_markers == 1);
    assert(ctx.restart_interval == 10);
}

int main() {
    test_entropy();
    test_h264_sps();
    test_jpeg_header();
    printf("All tests passed!\n");
    return 0;
}
