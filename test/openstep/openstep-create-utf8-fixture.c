/* Create a target-local filename with exact UTF-8 bytes C3 A9.  This avoids
   any encoding conversion in the host GCD file-transfer pathname and is used
   only by the physical Workspace SDL_DROPFILE validation. */
#include <stdio.h>

int main(void)
{
    static const char path[] = "/me/SDL2-\303\251-drop.txt";
    FILE *file;
    unsigned int i;

    file = fopen(path, "w");
    if (file == NULL) {
        perror(path);
        return 1;
    }
    fputs("SDL2 OPENSTEP exact UTF-8 filename fixture.\n", file);
    if (fclose(file) != 0) {
        perror(path);
        return 2;
    }
    printf("openstep-create-utf8-fixture: path bytes");
    for (i = 0; i < sizeof(path) - 1; ++i) {
        printf(" %02x", (unsigned int)(unsigned char)path[i]);
    }
    printf("\n");
    return 0;
}
