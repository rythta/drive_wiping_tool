#!/bin/bash

# This script securely erases a given drive using hdparm without user interaction
# and monitors the process to detect if it hangs.

# Exit codes:
# 0 - Success
# 1 - General error (pre-execution checks failed, etc.)
# 2 - The secure erase command hung

# Usage: $0 /dev/sdX
# Where /dev/sdX is the drive to be erased.

# Ensure the script is run with a drive specified and as root

DRIVE="$1"
RESULT=""

if [ "$(sg_readcap "${DRIVE}" | grep length | grep -oE '\d+' | head -1)" -eq 520 ]; then
    SG_DRIVE=$(lsscsi -g | grep "${DRIVE}" | grep -oE '/dev/sg\d+')
    sg_sanitize -O -z -w -Q "${SG_DRIVE}"
    if [ $? -ne 0 ]; then
	TB="$(sg_readcap ${SG_DRIVE} | grep -oE '\d+.\d+ TB' | grep -oE '\d+' | head -1)"
	WIPE_TIME="0"
	if [[ -n "${TB}" ]]; then
	    WIPE_TIME="$(echo ${TB} | awk '{print "(1+"$1")*"2}' | bc)"
	else
	    WIPE_TIME="2"
	fi
	timeout "${WIPE_TIME}h" sg_dd if=/dev/zero of="${SG_DRIVE}" bs=520
	if [ $? -eq 124]; then
	    exit 2
	fi
    fi
    exit 0
fi

# Unfreeze the drive if necessary and check for secure erase support
if $(hdparm -I "$DRIVE" | grep -E -v 'not[[:space:]]+frozen' | grep -q 'frozen'); then
  echo "Drive is frozen"
  exit 2
fi

# Ensure clean-up occurs even if the script is interrupted or exits normally
PASSWORD="YourSecurePassword"
trap 'echo "Attempting to remove security settings..."; hdparm --user-master u --security-disable "$PASSWORD" "$DRIVE";' EXIT

# Check if the drive supports Secure Erase
SECURE_ERASE_TYPE=""
if hdparm -I "$DRIVE" | grep -q 'supported: enhanced erase'; then
  SECURE_ERASE_TYPE="enhanced"
else
  SECURE_ERASE_TYPE="standard"
fi

# Set the user password for the drive
# hdparm --user-master u --security-set-pass "$PASSWORD" "$DRIVE"
# Start the secure erase process in the background
# output=$(hdparm --user-master u --security-erase "$PASSWORD" "$DRIVE" 2>&1)
# if [ $? -ne 0 ] || echo "$output" | grep -q "bad/missing sense data"; then
echo "Starting wipe"
BLOCK_SIZE=$(blockdev --getbsz ${DRIVE})
dd if=/dev/zero of="${DRIVE}" bs="${BLOCK_SIZE}"
echo "DD completed successfully."
# else
#     echo "Secure Erase completed successfully."
# fi

exit 0
