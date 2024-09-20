#!/bin/bash
DISK=$1
TEST_TYPE=$2

if [[ "${TEST_TYPE}" = "results" ]];then 
    echo "Displaying SMART test results for $DISK..."
    RESULTS=$(smartctl -l selftest $DISK)

    echo "${RESULTS}"
    echo "${RESULTS}" | grep -q failure
    # Invert the result: if grep finds "failure", it exits with 0 (success), so we switch the logic.
    if [ $? -eq 0 ]; then
	# If grep was successful (found "failure"), we exit with an error code.
	echo "Failure detected."
	exit 1
    else
	# If grep failed (no "failure" found), we exit with a success code.
	echo "No failure detected."
	exit 0
    fi
fi

SMARTCTL_CAPABILITIES=$(smartctl -c $DISK)

echo "${SMARTCTL_CAPABILITIES}" | grep -q 'Short self-test routine'
SHORT_TEST_ENABLED=$?

echo "${SMARTCTL_CAPABILITIES}" | grep -q 'Conveyance self-test routine'
CONVEYANCE_TEST_ENABLED=$?

# Decide which test to run based on the input and availability
if [ "$TEST_TYPE" = "conveyance" ] && [ $CONVEYANCE_TEST_ENABLED -eq 0 ]; then
    TEST_TO_RUN="conveyance"
elif [ $SHORT_TEST_ENABLED -eq 0 ]; then
    TEST_TO_RUN="short"
else
    echo "No supported tests available on this device."
    exit 0
fi

hdparm -B 255 $DISK  >/dev/null 2>&1

# Start the chosen SMART test
echo "Starting SMART $TEST_TO_RUN test on $DISK..."
smartctl -t $TEST_TO_RUN $DISK
if [ $? -ne 0 ]; then
    echo "Error initiating SMART test on $DISK."
    exit 0
fi

# Background process to enforce the timeout
(
    sleep 900 # 15 minutes in seconds
    echo "Timeout reached, aborting the SMART test on $DISK..."
    smartctl -X $DISK
) &
TIMEOUT_PID=$!

#Wait for the test to start properly
sleep 10

#Keep the drive awake
while [ "$(smartctl -c $DISK | grep 'Self-test execution status:' | grep -oE '\d+')" != "0" ]; do
   dd if=$DISK of=/dev/null count=1 bs=512 >/dev/null 2>&1
   sleep 60

   # Check if the timeout process is still running
   if ! kill -0 $TIMEOUT_PID 2>/dev/null; then
       echo "Test aborted due to timeout."
       break
   fi
done

# Cancel the timeout process if it's still running
if kill -0 $TIMEOUT_PID > /dev/null 2>&1; then
    kill $TIMEOUT_PID 2>/dev/null
    wait $TIMEOUT_PID 2>/dev/null
fi


hdparm -B 128 $DISK  >/dev/null 2>&1

#Display the SMART test results
echo "Displaying SMART test results for $DISK..."
RESULTS=$(smartctl -l selftest $DISK)

echo "${RESULTS}"
echo "${RESULTS}" | grep -q failure
# Invert the result: if grep finds "failure", it exits with 0 (success), so we switch the logic.
if [ $? -eq 0 ]; then
    # If grep was successful (found "failure"), we exit with an error code.
    echo "Failure detected."
    exit 1
else
    # If grep failed (no "failure" found), we exit with a success code.
    echo "No failure detected."
    exit 0
fi
