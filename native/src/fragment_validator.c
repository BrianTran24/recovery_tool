#include "fragment_validator.h"
#include <string.h>
#include <math.h>
#include <stdio.h>

// Helper: Calculate Shannon Entropy
double calculate_entropy_fv(const uint8_t* data, size_t len) {
    if (len == 0) return 0.0;
    uint32_t counts[256] = {0};
    for (size_t i = 0; i < len; i++) counts[data[i]]++;

    double entropy = 0;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double p = (double)counts[i] / len;
            entropy -= p * (log(p) / log(2.0));
        }
    }
    return entropy;
}

// --- H.264 Logic ---

// Find H.264 NAL Unit Start Code
static const uint8_t* find_nal_unit(const uint8_t* buf, size_t len, size_t* out_header_len) {
    for (size_t i = 0; i < len - 4; i++) {
        if (buf[i] == 0x00 && buf[i+1] == 0x00) {
            if (buf[i+2] == 0x01) {
                *out_header_len = 3;
                return buf + i + 3;
            } else if (buf[i+2] == 0x00 && buf[i+3] == 0x01) {
                *out_header_len = 4;
                return buf + i + 4;
            }
        }
    }
    return NULL;
}

typedef struct {
    const uint8_t* buf;
    size_t len;
    size_t pos;
} BS;

static uint32_t bs_read_bit(BS* bs) {
    if (bs->pos >= bs->len * 8) return 0;
    uint32_t bit = (bs->buf[bs->pos / 8] >> (7 - (bs->pos % 8))) & 1;
    bs->pos++;
    return bit;
}

static uint32_t bs_read_bits(BS* bs, int n) {
    uint32_t val = 0;
    for (int i = 0; i < n; i++) val = (val << 1) | bs_read_bit(bs);
    return val;
}

static uint32_t bs_read_ue(BS* bs) {
    int zeros = 0;
    while (bs_read_bit(bs) == 0 && zeros < 32) zeros++;
    if (zeros == 0) return 0;
    return (uint32_t)((1 << zeros) - 1 + bs_read_bits(bs, zeros));
}

int parse_h264_sps(const uint8_t* sps, size_t len, H264Context* out) {
    BS bs = { .buf = sps, .len = len, .pos = 0 };
    // Skip NAL header (1 byte)
    bs.pos += 8;

    out->profile_idc = bs_read_bits(&bs, 8);
    bs_read_bits(&bs, 8); // constraint_set
    bs_read_ue(&bs);      // level_idc
    bs_read_ue(&bs);      // sps_id

    if (out->profile_idc == 100 || out->profile_idc == 110 || out->profile_idc == 122 || out->profile_idc == 244) {
        if (bs_read_ue(&bs) == 3) bs_read_bit(&bs); // chroma_format_idc
        bs_read_ue(&bs); // bit_depth_luma
        bs_read_ue(&bs); // bit_depth_chroma
        bs_read_bit(&bs); // qpprime_y_zero_transform_bypass_flag
        if (bs_read_bit(&bs)) { // seq_scaling_matrix_present_flag
            // skip scaling matrix...
        }
    }

    out->log2_max_frame_num = bs_read_ue(&bs) + 4;
    // ... simplified parsing for demo ...
    return 1;
}

int validate_h264_fragment(const H264Context* ctx, const uint8_t* buf, size_t len, int* last_frame_num) {
    size_t h_len = 0;
    const uint8_t* nalu = find_nal_unit(buf, len, &h_len);
    if (!nalu) return 0;

    uint8_t type = nalu[0] & 0x1F;
    if (type == 1 || type == 5) { // Slice
        BS bs = { .buf = nalu + 1, .len = len - (nalu - buf) - 1, .pos = 0 };
        bs_read_ue(&bs); // first_mb_in_slice
        bs_read_ue(&bs); // slice_type
        bs_read_ue(&bs); // pic_parameter_set_id

        int frame_num = bs_read_bits(&bs, ctx->log2_max_frame_num);

        // Consistency check
        if (*last_frame_num >= 0) {
            int diff = (frame_num - *last_frame_num + (1 << ctx->log2_max_frame_num)) % (1 << ctx->log2_max_frame_num);
            if (diff > 5) return 0; // Too far apart
        }
        *last_frame_num = frame_num;
        return 1;
    }

    // SPS, PPS, SEI are always valid markers for fragmentation
    if (type == 7 || type == 8 || type == 6) return 1;

    return 0;
}

// --- JPEG Logic ---

int parse_jpeg_header_info(const uint8_t* buf, size_t len, JPEGContext* out) {
    memset(out, 0, sizeof(JPEGContext));
    size_t pos = 2; // Skip SOI
    while (pos + 4 < len) {
        if (buf[pos] != 0xFF) break;
        uint8_t m = buf[pos+1];
        if (m == 0xDA) break; // SOS

        uint16_t slen = (buf[pos+2] << 8) | buf[pos+3];
        if (m == 0xDD && slen >= 4) {
            out->has_restart_markers = 1;
            out->restart_interval = (buf[pos+4] << 8) | buf[pos+5];
        } else if (m == 0xDB) {
            // Fingerprint DQT
            out->dqt_ids[0] = 1;
        }
        pos += slen + 2;
    }
    return 1;
}

int validate_jpeg_fragment(const JPEGContext* ctx, const uint8_t* buf, size_t len) {
    double entropy = calculate_entropy_fv(buf, len > 1024 ? 1024 : len);
    if (entropy < 7.0) return 0; // JPEG compressed data is high entropy

    // If file has restart markers, look for them
    if (ctx->has_restart_markers) {
        for (size_t i = 0; i < len - 2; i++) {
            if (buf[i] == 0xFF && (buf[i+1] >= 0xD0 && buf[i+1] <= 0xD7)) {
                return 1; // Found a valid restart marker in the fragment
            }
        }
    }

    return 1; // Fallback to entropy if no markers found but it looks like data
}
