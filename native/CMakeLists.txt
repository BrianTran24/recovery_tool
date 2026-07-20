cmake_minimum_required(VERSION 3.14)
project(sd_recovery C)

set(CMAKE_C_STANDARD 11)

# Include src directory so headers can be found
include_directories(src)

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
        src/recovery_ffi.c
)

if(APPLE)
    target_link_libraries(recovery "-framework CoreFoundation" "-framework DiskArbitration")
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
