cmake_minimum_required(VERSION 3.14)
project(sd_recovery C)

set(CMAKE_C_STANDARD 11)

# Include src directory so headers can be found
include_directories(src)

# Try to find libewf
find_path(LIBEWF_INCLUDE_DIR NAMES libewf.h)
find_library(LIBEWF_LIBRARY NAMES ewf)

if(LIBEWF_INCLUDE_DIR AND LIBEWF_LIBRARY)
    message(STATUS "Found libewf: ${LIBEWF_LIBRARY}")
    include_directories(${LIBEWF_INCLUDE_DIR})
    add_definitions(-DHAVE_LIBEWF)
else()
    message(WARNING "libewf not found. E01 support will be disabled.")
endif()

add_library(recovery SHARED
        src/sector_reader.c
        src/fat32_parser.c
        src/exfat_parser.c
        src/smart_assembler.c
        src/carver.c
        src/fragment_validator.c
        src/signature_registry.c
        src/device_handlers.c
        src/video_repair.c
        src/hardware_health_checker.c
        src/partition_detector.c
        src/e01_handler.c
        src/recovery_ffi.c
)

if(APPLE)
    target_link_libraries(recovery "-framework CoreFoundation" "-framework DiskArbitration")
    if(LIBEWF_LIBRARY)
        target_link_libraries(recovery ${LIBEWF_LIBRARY})
    endif()
    set_target_properties(recovery PROPERTIES
            OUTPUT_NAME "recovery"
            SUFFIX ".dylib"
            INSTALL_RPATH "@executable_path"
    )
endif()

if(WIN32)
    set_target_properties(recovery PROPERTIES
            OUTPUT_NAME "recovery"
            SUFFIX ".dll"
    )
endif()
