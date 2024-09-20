#!/bin/bash

# Check if the disk identifier is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 /dev/diskX"
    exit 1
fi

# Assign the first argument to a variable
DISK=$1

if [ ! -b "${DISK}" ]; then
    echo "Disk does not exist"
    exit 1
fi 

if ! docker images | grep -q 'ntrrg/hdsentinel'; then
    docker load < /root/dw9k/ntrrg_hdsentinel.tar
fi

SENTINAL=$(docker run --rm --privileged -v /dev/:/dev/ \
		ntrrg/hdsentinel -dev $DISK)
if [ -z "$SENTINAL" ]; then
    echo "No data was returned from hdsentinel. Check if the disk is connected and try again."
    exit 1
fi

HEALTH=$(echo "${SENTINAL}" | grep Health | grep -oE '\d+')
PERFORMANCE=$(echo "${SENTINAL}" | grep Performance | grep -oE '\d+')
# Validate the extracted values
if [ -z "$HEALTH" ] || ! [[ "$HEALTH" =~ ^[0-9]+$ ]]; then
    echo "Failed to extract a valid Health value."
    exit 1
fi

if [ -z "$PERFORMANCE" ] || ! [[ "$PERFORMANCE" =~ ^[0-9]+$ ]]; then
    echo "Failed to extract a valid Performance value."
    exit 1
fi

# Optionally, add range validation if there's an expected range
if [ "$HEALTH" -lt 0 ] || [ "$HEALTH" -gt 100 ]; then
    echo "Health value is out of the expected range (0-100)."
    exit 1
fi

if [ "$PERFORMANCE" -lt 0 ] || [ "$PERFORMANCE" -gt 100 ]; then
    echo "Performance value is out of the expected range (0-100)."
    exit 1
fi

THRESHOLD=95
if [ "$(lsblk -no ROTA ${DISK} | head -1)" -eq 0 ]; then
    THRESHOLD=80
fi


if [ "$HEALTH" -lt 0 ]; then
	echo "Health at ${HEALTH}%. Exiting."
	exit 1
fi
if [ "$PERFORMANCE" -lt 0 ]; then
	echo "Performance at ${PERFORMANCE}%. Exiting."
	exit 1
fi

echo "SENTINAL: Drive: ${DISK}, Health: ${HEALTH}, Performance: ${PERFORMANCE}"
