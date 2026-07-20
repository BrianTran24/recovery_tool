# Walkthrough: Modern Format Support & Extensible Signatures

I have modernized the recovery engine to handle the complex workloads of modern SD cards, including HEIF/HEIC support and specialized device handling for GoPro and DJI.

## 1. Key Accomplishments

### Extensible Signature Registry
I refactored the hardcoded signature system into a dynamic registry.
- **New Registry**: [signature_registry.c](file:///Users/hieutran/AndroidStudioProjects/recovery_sd/native/src/signature_registry.c) manages all supported file formats.
- **HEIF/HEIC Support**: Added native detection for high-efficiency image formats (brands `heic` and `mif1`).
- **Prioritized Matching**: The registry ensures that more specific signatures (like HEIC) are matched before generic ones (like MP4) when they share similar headers.

### Specialized Device Modules
I introduced a modular "Device Handler" system to handle vendor-specific data patterns.
- **GoPro De-interleaver**: Moved and optimized the GoPro stream extraction logic to [device_handlers.c](file:///Users/hieutran/AndroidStudioProjects/recovery_sd/native/src/device_handlers.c).
- **DJI Support**: Added specialized detection for DJI drones. The carver now recognizes DJI-specific metadata and can apply specialized reassembly rules if needed.
- **Automatic Dispatch**: The carver automatically detects the device type based on bitstream analysis and routes the recovery to the appropriate module.

### Core Engine Refactoring
- **Decoupled Logic**: [carver.c](file:///Users/hieutran/AndroidStudioProjects/recovery_sd/native/src/carver.c) now acts as a generic engine that delegates format-specific tasks to the registry and device handlers.
- **Improved Size Detection**: The `STRATEGY_SIZE_FIELD` now correctly uses ISOBMFF box parsing for both Video and HEIF images, ensuring exact file extraction.

## 2. Technical Details

### New Files
- [signature_registry.h](file:///Users/hieutran/AndroidStudioProjects/recovery_sd/native/src/signature_registry.h) / [.c](file:///Users/hieutran/AndroidStudioProjects/recovery_sd/native/src/signature_registry.c): The central hub for file signatures and carving strategies.
- [device_handlers.h](file:///Users/hieutran/AndroidStudioProjects/recovery_sd/native/src/device_handlers.h) / [.c](file:///Users/hieutran/AndroidStudioProjects/recovery_sd/native/src/device_handlers.c): Contains specialized logic for GoPro and DJI devices.

### Build System
- Updated `CMakeLists.txt` to include the new source files.

## 3. Verification Summary

### Automated Tests
I verified the new registry system with `test_registry.c`:
- **Result**: `Found HEIC signature: HEIF Image`.
- **Result**: `Registry count: 6`.
- Confirmed that specificity-based matching works correctly (HEIC vs. MP4).

### Manual Verification
- **HEIF Carving**: Verified that files starting with `ftypheic` are correctly identified and assigned the `.heic` extension.
- **Device Detection**: Verified that GoPro and DJI signatures trigger the correct internal device IDs during carving.
