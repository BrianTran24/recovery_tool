// recovery_ffi.h — interface duy nhất Dart cần biết
#pragma once
#include <stdint.h>

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

// Event types — phải match với Dart enum
#define EVENT_PROGRESS   1
#define EVENT_FILE_FOUND 2
#define EVENT_ERROR      3
#define EVENT_DONE       4

// Struct truyền qua callback — packed để Dart struct alignment dễ map
#pragma pack(push, 1)
typedef struct {
    int32_t  event_type;
    double   percent;          // EVENT_PROGRESS
    int64_t  scanned_bytes;
    int32_t  speed_mbps;
    char     file_type[16];    // EVENT_FILE_FOUND: "JPEG", "MP4"...
    char     filename[256];
    int64_t  file_size;
    int64_t  sector_offset;
    int32_t  error_code;       // EVENT_ERROR
    char     error_msg[256];
    int32_t  total_found;      // EVENT_DONE
    int32_t  fat_count;
    int32_t  carve_count;
    int64_t  duration_ms;
} RecoveryEvent;
#pragma pack(pop)

// Dart truyền vào con trỏ hàm callback kiểu này
typedef void (*RecoveryCallback)(const RecoveryEvent* event);

// ── Public API ───────────────────────────────────────────────────────

// Liệt kê removable drives — trả về JSON string (caller free)
EXPORT char* recovery_list_drives(void);

// Mở drive, trả về handle (>= 0) hoặc lỗi (< 0)
EXPORT int32_t recovery_open(const char* device_path);

// Unmount ổ đĩa (macOS)
EXPORT int32_t recovery_unmount(const char* device_path);

// Lấy tổng size của drive đã mở (bytes)
EXPORT int64_t recovery_disk_size(int32_t handle);

// Bắt đầu scan — blocking, gọi callback liên tục
// Dart phải gọi từ Isolate riêng
EXPORT int32_t recovery_scan(
        int32_t           handle,
        const char*       output_dir,
        RecoveryCallback  callback,
        int32_t           enable_fat,    // 1 = bật FAT32 parser
        int32_t           enable_carve   // 1 = bật signature carving
);

// Yêu cầu dừng scan (set flag, không block)
EXPORT void recovery_cancel(int32_t handle);

// Đóng và giải phóng handle
EXPORT void recovery_close(int32_t handle);

// Giải phóng string từ recovery_list_drives
EXPORT void recovery_free_string(char* ptr);

// Lưu file carved vào đường dẫn đích
EXPORT int32_t recovery_save_file(int32_t handle, int64_t sector_offset, int64_t file_size, const char* output_path);
