#include "signature_registry.h"
#include <string.h>

// External functions from carver.c
extern uint64_t mp4_read_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len, int* out_has_moov);
extern uint64_t h264_smart_carve_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len, int* out_has_moov);
extern uint64_t jpeg_smart_carve_size(const CarverContext* ctx, uint64_t file_start, const uint8_t* buf, size_t len, int* out_has_moov);
extern int jpeg_validate(const uint8_t* buf, size_t len);
extern int mp4_validate(const uint8_t* buf, size_t len);

void init_signature_registry(SignatureRegistry* reg) {
    reg->count = 0;

    // JPEG
    FileSignature jpg = {
        .name = "JPEG", .extension = ".jpg",
        .header = {0xFF, 0xD8, 0xFF}, .header_len = 3,
        .strategy = STRATEGY_SMART_JPEG, .max_size = 100ULL * 1024 * 1024,
        .read_size = jpeg_smart_carve_size,
        .validate = jpeg_validate
    };
    register_signature(reg, &jpg);

    // PNG
    FileSignature png = {
        .name = "PNG", .extension = ".png",
        .header = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, .header_len = 8,
        .footer = {0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82}, .footer_len = 8,
        .strategy = STRATEGY_FOOTER, .max_size = 100ULL * 1024 * 1024,
    };
    register_signature(reg, &png);

    // HEIF/HEIC Support (Register BEFORE generic Video/MP4 to ensure more specific match)
    FileSignature heic = {
        .name = "HEIF Image", .extension = ".heic",
        .header = {0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63}, .header_len = 8, .header_offset = 4,
        .strategy = STRATEGY_SIZE_FIELD, .max_size = 200ULL * 1024 * 1024,
        .read_size = mp4_read_size, // Reuses ISOBMFF logic
        .validate = mp4_validate
    };
    register_signature(reg, &heic);

    FileSignature mif1 = {
        .name = "HEIF Image", .extension = ".heic",
        .header = {0x66, 0x74, 0x79, 0x70, 0x6D, 0x69, 0x66, 0x31}, .header_len = 8, .header_offset = 4,
        .strategy = STRATEGY_SIZE_FIELD, .max_size = 200ULL * 1024 * 1024,
        .read_size = mp4_read_size,
        .validate = mp4_validate
    };
    register_signature(reg, &mif1);

    // MP4 Video
    FileSignature mp4 = {
        .name = "Video", .extension = ".mp4",
        .header = {0x66, 0x74, 0x79, 0x70}, .header_len = 4, .header_offset = 4,
        .strategy = STRATEGY_MAX_SIZE, .max_size = 64000ULL * 1024 * 1024,
        .read_size = mp4_read_size,
        .validate = mp4_validate
    };
    register_signature(reg, &mp4);

    // H.264 Video
    FileSignature h264 = {
        .name = "Video (Smart)", .extension = ".h264",
        .header = {0x00, 0x00, 0x00, 0x01, 0x67}, .header_len = 5,
        .strategy = STRATEGY_SMART_VIDEO, .max_size = 64000ULL * 1024 * 1024,
        .read_size = h264_smart_carve_size,
    };
    register_signature(reg, &h264);
}

void register_signature(SignatureRegistry* reg, const FileSignature* sig) {
    if (reg->count < MAX_REGISTRY_SIGNATURES) {
        reg->signatures[reg->count++] = *sig;
    }
}
