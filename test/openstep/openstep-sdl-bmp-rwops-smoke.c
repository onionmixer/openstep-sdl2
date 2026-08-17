/* Standard SDL2 in-memory BMP save/load smoke. This validates the upstream
   SDL_bmp.c implementation without relying on any OPENSTEP-only API. */
#include <stdio.h>

#include "SDL.h"

static int fail(const char *what)
{
    fprintf(stderr, "openstep-sdl-bmp-rwops-smoke: %s: %s\n", what, SDL_GetError());
    return 1;
}

int main(int argc, char **argv)
{
    Uint8 storage[4096];
    SDL_Surface *source;
    SDL_Surface *loaded;
    SDL_RWops *stream;
    Uint32 red;
    Uint32 blue;
    Uint8 r;
    Uint8 g;
    Uint8 b;
    Uint8 a;
    int result = 0;

    (void)argc;
    (void)argv;
    source = SDL_CreateRGBSurfaceWithFormat(0, 2, 2, 32, SDL_PIXELFORMAT_ARGB8888);
    if (!source) return fail("source surface creation failed");
    red = SDL_MapRGBA(source->format, 255, 0, 0, 255);
    blue = SDL_MapRGBA(source->format, 0, 0, 255, 255);
    if (SDL_FillRect(source, NULL, red) != 0) result = 1;
    if (!result) {
        SDL_Rect pixel;
        pixel.x = 1;
        pixel.y = 1;
        pixel.w = 1;
        pixel.h = 1;
        if (SDL_FillRect(source, &pixel, blue) != 0) result = 2;
    }
    stream = result ? NULL : SDL_RWFromMem(storage, sizeof(storage));
    if (!stream) result = 3;
    if (!result && SDL_SaveBMP_RW(source, stream, 0) != 0) result = 4;
    if (!result && SDL_RWseek(stream, 0, RW_SEEK_SET) < 0) result = 5;
    loaded = result ? NULL : SDL_LoadBMP_RW(stream, 0);
    if (!loaded) result = 6;
    if (!result) {
        Uint32 pixel = *(Uint32 *)((Uint8 *)loaded->pixels + loaded->pitch + 4);
        SDL_GetRGBA(pixel, loaded->format, &r, &g, &b, &a);
        if (r != 0 || g != 0 || b != 255 || a != 255) result = 7;
    }
    if (loaded) SDL_FreeSurface(loaded);
    if (stream) SDL_RWclose(stream);
    SDL_FreeSurface(source);
    if (result) return fail("BMP/RWops round trip failed");
    printf("openstep-sdl-bmp-rwops-smoke: PASS save/load ARGB pixel round trip\n");
    return 0;
}
