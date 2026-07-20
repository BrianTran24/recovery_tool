#pragma once
#include <stdint.h>
#include <stddef.h>

#define MAX_HEADER_LEN  16
#define MAX_FOOTER_LEN  16

typedef enum {
    STRATEGY_FOOTER,
    STRATEGY_SIZE_FIELD,
    STRATEGY_MAX_SIZE,
    STRATEGY_SMART_VIDEO,
    STRATEGY_SMART_JPEG,
    STRATEGY_DEVICE_SPECIFIC
} CarveStrategy;

typedef struct {
    int      fd;
    uint64_t disk_size;
    uint32_t sector_size;
    uint32_t read_chunk;
} CarverContext;

typedef struct {
    const char*   name;
    const char*   extension;
    uint8_t       header[MAX_HEADER_LEN];
    size_t        header_len;
    size_t        header_offset;
    uint8_t       footer[MAX_FOOTER_LEN];
    size_t        footer_len;
    CarveStrategy strategy;
    uint64_t      max_size;
    uint64_t      min_size;
    uint64_t (*read_size)(const CarverContext* ctx, uint64_t file_start, const uint8_t* header_buf, size_t buf_len, int* out_has_moov);
    int (*validate)(const uint8_t* buf, size_t len);
    int           device_id; // 0=None, 1=GoPro, 2=DJI
} FileSignature;

#define MAX_REGISTRY_SIGNATURES 32

typedef struct {
    FileSignature signatures[MAX_REGISTRY_SIGNATURES];
    size_t count;
} SignatureRegistry;

// Registry API
void init_signature_registry(SignatureRegistry* reg);
void register_signature(SignatureRegistry* reg, const FileSignature* sig);
const FileSignature* find_signature_by_header(const SignatureRegistry* reg, const uint8_t* buf, size_t len);
