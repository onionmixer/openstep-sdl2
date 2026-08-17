/* Non-GUI target smoke for public utility APIs added to the OPENSTEP closure. */
#include "SDL.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    char words[] = ":one::two:";
    char *state = NULL;
    char *token;
    Uint32 whole;
    Uint32 split;

    (void)argc;
    (void)argv;

    whole = SDL_crc32(0, "123456789", 9);
    split = SDL_crc32(SDL_crc32(0, "1234", 4), "56789", 5);
    if (whole != split) {
        fprintf(stderr, "utility-smoke: crc incremental mismatch\n");
        return 1;
    }

    token = SDL_strtokr(words, ":", &state);
    if (!token || strcmp(token, "one") != 0) return 2;
    token = SDL_strtokr(NULL, ":", &state);
    if (!token || strcmp(token, "two") != 0) return 3;
    if (SDL_strtokr(NULL, ":", &state) != NULL) return 4;

    printf("openstep-sdl-utility-smoke: PASS crc32+strtokr\n");
    return 0;
}
