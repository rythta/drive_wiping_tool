import subprocess
import random
import argparse
import sys
import logging

# Setup basic logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def generate_pseudorandom_locations(total_size, block_size, subsection_size, sample_size):
    subsections = 1000
    locations = []

    for i in range(subsections):
        start = i * subsection_size
        subsection_end = start + subsection_size

        if 2 * sample_size > (subsection_end - start):
            raise ValueError("Not enough space for two non-overlapping samples in subsection.")

        # Generate first sample start position
        first_sample_start = random.randint(start, subsection_end - sample_size)

        # Attempt to generate the second sample start position
        while True:
            second_sample_start = random.randint(start, subsection_end - sample_size)
            if second_sample_start >= first_sample_start + sample_size or second_sample_start + sample_size <= first_sample_start:
                break

        locations.append(first_sample_start)
        locations.append(second_sample_start)

    # Optionally append locations based on the total size and block size
    locations.append(0)  # Start of the space
    if total_size - block_size > 0:
        locations.append(total_size - sample_size)  # Position near the end of the space

    return locations

def get_device_size(device):
    try:
        command = f"sg_readcap {device} | grep -oE 'size: \d+' | sed 's/size: //g'"
        device_size = subprocess.check_output(command, shell=True).strip().decode('utf-8')
        return int(device_size)
    except subprocess.CalledProcessError as e:
        print(f"Error retrieving device size: {e}")
        return None
    except ValueError:
        print("Received non-integer value for device size.")
        return None

def get_block_size(device):
    try:
        command = f"sg_readcap {device} | grep length | grep -oE '\d+' | head -1"
        block_size = subprocess.check_output(command, shell=True).strip().decode('utf-8')
        if block_size == "520":
            return int(block_size)
    except subprocess.CalledProcessError as e:
        print(f"Error retrieving block size with sg_readcap: {e}")
    except ValueError:
        print("Received non-integer value for block size from sg_readcap.")

    try:
        block_size = subprocess.check_output(['blockdev', '--getbsz', device]).strip().decode('utf-8')
        return int(block_size)
    except subprocess.CalledProcessError as e:
        print(f"Error retrieving block size: {e}")
    except ValueError:
        print("Received non-integer value for block size.")

    return None

def verify_location(location, device, block_size, sample_size):
    """
    Verifies if the data read from a specific location on the device is all zeroes.
    This function wraps a Bash script that uses `dd` or `sg_dd` for reading and `process_data`
    for processing the data.

    Parameters:
    - location: The offset from where to start reading (in bytes).
    - device: The device path (e.g., '/dev/sdb').
    - block_size: The block size to use for reading (in bytes).
    - sample_size: The number of bytes to read.

    Returns:
    - A string message indicating if the data is all zeros or contains non-zero bytes.
    """
    # Define the bash command to execute
    command = f"/root/dw9k/verify_location.sh {location} {device} {block_size} {sample_size}"

    try:
        # Execute the bash script
        result = subprocess.run(command, shell=True, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        # Output from the script will be in result.stdout
        return True
    except subprocess.CalledProcessError as e:
        print(command)
        print(f"Error verifying location: {e}")
        return False

def verify_locations(locations, block_size, sample_size, device):
    if block_size == 520:
        command = f"lsscsi -g | grep {device} | grep -oE '/dev/sg\d+'"
        try:
            device = subprocess.check_output(command, shell=True, executable='/bin/bash').strip().decode('utf-8')
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to execute command: {e}")
            return False

    success_count = 0
    read_failure_count = 0

    for location in locations:
        if not verify_location(location, device, block_size, sample_size):
            return False
        else:
            success_count += 1

    logging.info(f"Verification {success_count} locations in {device} of size {sample_size} bytes")
    return True

def main():
    parser = argparse.ArgumentParser(description="Verify specific locations on a device.")
    parser.add_argument("--device", required=True, help="Device path (e.g., /dev/sdx)")
    parser.add_argument("--subsections", type=int, default=1000, help="Number of subsections to generate")
    parser.add_argument("--samples_per_subsection", type=int, default=2, help="Number of samples per subsection")
    args = parser.parse_args()

    device_size = get_device_size(args.device)
    if device_size is None:
        print("Failed to retrieve device size. Exiting.")
        sys.exit(1)

    block_size = get_block_size(args.device)
    if block_size is None:
        print("Could not determine block size, using default 4096 bytes")
        block_size = 4096

    subsection_size = device_size // 1000;
    sample_size = int(0.05 * subsection_size);
    locations = generate_pseudorandom_locations(device_size, block_size, subsection_size, sample_size)
    if verify_locations(locations, block_size, sample_size, args.device):
        print("Verification successful")
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
