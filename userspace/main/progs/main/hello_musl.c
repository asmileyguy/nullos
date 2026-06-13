#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    printf("Hello from musl on NullOS!\n");

    char *msg = malloc(128);
    if (!msg) {
        printf("Malloc failed!\n");
        return 1;
    }

    strcpy(msg, "This string was allocated with malloc() in musl libc!");
    printf("Message: %s\n", msg);

    free(msg);
    printf("Memory freed successfully.\n");

    return 0;
}
