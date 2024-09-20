#!/bin/bash

# Usage: verify_location.sh <location> <device> <block_size> <sample_size>

verify_location() {
    local location=$1
    local device=$2
    local block_size=$3
    local sample_size=$4

    local start_block=$((location / block_size))
    local end_location=$((location + sample_size))
    local end_block=$(((end_location + block_size - 1) / block_size))
    local count=$((end_block - start_block))

    # Determine appropriate command based on device type
    local tool=$(echo "$device" | grep -q "sg" && echo "sg_dd" || echo "dd")

    # Construct and execute the dd command for the entire sample in one go
    $tool if="$device" bs="$block_size" skip="$start_block" count="$count" 2>/dev/null | /root/dw9k/is_zero $block_size
    local result=$?

    echo "$tool if=$device bs=$block_size skip=$start_block count=$count 2>/dev/null | /root/dw9k/is_zero $block_size"

    if [ $result -eq 1 ]; then
	exit 1
    else
	exit 0
    fi
}

# Main execution block
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <location> <device> <block_size> <sample_size>"
    exit 1
fi

verify_location "$1" "$2" "$3" "$4"
