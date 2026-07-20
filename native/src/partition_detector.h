#ifndef PARTITION_DETECTOR_H
#define PARTITION_DETECTOR_H

#include <stdint.h>
#include "recovery_ffi.h"

typedef struct {
    int64_t start_sector;
    int fs_type;
    uint32_t cluster_size; // in sectors
} PartitionCandidate;

int DetectPartitions(int fd, int64_t disk_sectors, PartitionCandidate* candidates, int max_candidates);

#endif
