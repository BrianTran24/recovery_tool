#pragma once

#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#include <windows.h>
#include <stdio.h>
#include <direct.h>
#include <sys/types.h>

#define LSEEK _lseeki64
#define READ  _read
#define CLOSE _close
#define OPEN  _open
#define MKDIR(path, mode) _mkdir(path)

#define STRDUP _strdup
#define STRCMP_IGNORE_CASE _stricmp

// Use a custom type for 64-bit offsets to avoid conflicts with system off_t
typedef __int64 off_t_64;

// ssize_t is not defined in MSVC
#ifndef _SSIZE_T_DEFINED
#ifdef _WIN64
typedef __int64 ssize_t;
#else
typedef int ssize_t;
#endif
#define _SSIZE_T_DEFINED
#endif

static inline ssize_t PREAD(int fd, void* buf, size_t count, off_t_64 offset) {
    off_t_64 old = _lseeki64(fd, 0, SEEK_CUR);
    if (_lseeki64(fd, offset, SEEK_SET) < 0) return -1;
    ssize_t n = _read(fd, buf, (unsigned int)count);
    _lseeki64(fd, old, SEEK_SET);
    return n;
}

#else
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

#define LSEEK lseek
#define READ  read
#define CLOSE close
#define OPEN  open
#define MKDIR(path, mode) mkdir(path, mode)

#define STRDUP strdup
#define STRCMP_IGNORE_CASE strcasecmp
#define PREAD pread

typedef off_t off_t_64;
#endif
