#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <buffer size in bytes>\n", argv[0]);
        return 1;
    }

    // Convert buffer size from command line argument
    size_t bufferSize = strtoul(argv[1], NULL, 10);
    if (bufferSize == 0) {
        fprintf(stderr, "Invalid buffer size.\n");
        return 1;
    }

    // Allocate memory for the buffer based on the provided size
    uint32_t *buf = malloc(bufferSize);
    if (buf == NULL) {
        perror("Failed to allocate memory");
        return 1;
    }

    uint32_t result = 0;
    size_t bytesRead;

    // Read data from stdin in chunks of the specified buffer size
    while ((bytesRead = fread(buf, sizeof(uint32_t), bufferSize / sizeof(uint32_t), stdin)) > 0) {
        for (size_t i = 0; i < bytesRead; i++) {
            result |= buf[i];
        }
    }

    // Check for errors in reading
    if (ferror(stdin)) {
        perror("Error reading stdin");
        free(buf);  // Free the allocated memory
        return 1;
    }

    // Output the result
    printf("The bitwise OR of the data is: %u\n", result);

    free(buf);  // Free the allocated memory

    // Return 1 if the result is nonzero, 0 if it is zero
    return result != 0 ? 1 : 0;
}

