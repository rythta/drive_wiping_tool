#!/bin/bash

SCSI=$(dmesg | grep "phy($1)" | grep -oE '\d+:\d+:\d+:\d+')
BLOCK_DEV=$(dmesg | grep "${SCSI}" | grep -oE ' \[.*\]' | tail -1 | grep -oE '[a-z]{3}')
DISK="/dev/${BLOCK_DEV}"
echo "=================================================="
echo "DISK"
echo "=================================================="
echo "$DISK"
echo ""
echo "=================================================="
echo "VERIFICATION"
echo "=================================================="
python /root/dw9k/verify.py --device "${DISK}"
echo ""
echo "=================================================="
echo "DD"
echo "=================================================="
dd if="${DISK}" count=1000000
echo ""
echo "=================================================="
echo "SMART CHECK"
echo "=================================================="
/root/dw9k/smart_check.sh "${DISK}" short
echo ""
echo "=================================================="
echo "SENTINAL"
echo "=================================================="
/root/dw9k/sentinal.sh "${DISK}"
echo ""
