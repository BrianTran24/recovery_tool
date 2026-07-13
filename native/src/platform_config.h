#pragma once

#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#include <windows.h>
#include <stdio.h>

#define LSEEK _lseeki64
#define READ  _read
#define CLOSE _close
#define OPEN  _open
#define MKDIR(path, mode) _mkdir(path)

// ssize_t is not defined in MSVC
#ifndef _SSIZE_T_DEFINED
#ifdef _WIN64
typedef __int64 ssize_t;
#else
typedef int ssize_t;
#endif
#define _SSIZE_T_DEFINED
#endif

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
#endif
