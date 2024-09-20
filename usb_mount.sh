#!/bin/sh

# The device that triggered the script is in $DEVNAME
DEVICE="/dev/${MDEV}1"

# Define the mount point
MOUNT_POINT="/mnt/"

# Create the mount directory if it doesn't exist
mkdir -p $MOUNT_POINT

# Mount the device
mount $DEVICE $MOUNT_POINT

# Check if the mount was successful
if [ $? -eq 0 ]; then
    beep -l 250
else
    echo "Mounting failed"
    beep -l 250
    sleep 0.25
    beep -l 250
    sleep 0.25
    beep -l 250
fi

