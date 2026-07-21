#include "recovery_ffi.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef HAVE_LIBEWF
#include <libewf.h>
#endif

EXPORT int32_t recovery_convert_e01(const char* e01_path, const char* output_path, RecoveryCallback callback) {
#ifndef HAVE_LIBEWF
    RecoveryEvent ev = {0};
    ev.event_type = EVENT_ERROR;
    ev.error_code = -1;
    strncpy(ev.error_msg, "libewf không được tích hợp trong bản build này.", 255);
    if (callback) callback(&ev);
    return -1;
#else
    libewf_error_t* error = NULL;
    libewf_handle_t* handle = NULL;
    int result = 0;

    if (libewf_handle_initialize(&handle, &error) != 1) {
        goto error_cleanup;
    }

    // libewf_handle_open handles multiple files (E01, E02...) automatically
    // when given the first file path.
    char* filenames[] = { (char*)e01_path };
    if (libewf_handle_open(handle, filenames, 1, LIBEWF_OPEN_READ, &error) != 1) {
        goto error_cleanup;
    }

    size64_t media_size = 0;
    if (libewf_handle_get_media_size(handle, &media_size, &error) != 1) {
        goto error_cleanup;
    }

    FILE* out = fopen(output_path, "wb");
    if (!out) {
        goto error_cleanup;
    }

    uint8_t* buffer = (uint8_t*)malloc(1024 * 1024); // 1MB heap buffer
    if (!buffer) {
        goto error_cleanup;
    }
    size64_t current_offset = 0;

    while (current_offset < media_size) {
        size_t to_read = (size_t)((media_size - current_offset) < (1024 * 1024) ? (media_size - current_offset) : (1024 * 1024));
        ssize_t n = libewf_handle_read_random(handle, buffer, to_read, (off64_t)current_offset, &error);
        if (n <= 0) break;

        fwrite(buffer, 1, (size_t)n, out);
        current_offset += n;

        if (callback) {
            RecoveryEvent ev = {0};
            ev.event_type = EVENT_PROGRESS;
            ev.percent = (double)current_offset / (double)media_size * 100.0;
            ev.scanned_bytes = (int64_t)current_offset;
            callback(&ev);
        }
    }

    free(buffer);
    fclose(out);
    libewf_handle_close(handle, &error);
    libewf_handle_free(&handle, &error);

    RecoveryEvent done = {0};
    done.event_type = EVENT_DONE;
    if (callback) callback(&done);

    return 0;

error_cleanup:
    if (handle) {
        libewf_handle_free(&handle, NULL);
    }
    if (error) {
        RecoveryEvent ev = {0};
        ev.event_type = EVENT_ERROR;
        ev.error_code = -1;
        // Simplified error extraction
        strncpy(ev.error_msg, "Lỗi libewf khi xử lý file E01", 255);
        if (callback) callback(&ev);
        libewf_error_free(&error);
    }
    return -1;
#endif
}
