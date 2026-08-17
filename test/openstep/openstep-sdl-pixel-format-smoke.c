/* Standard SDL2 pixel-format round-trip smoke for OPENSTEP.
   This does not require an AppKit display and is safe over telnet. */
#include <stdio.h>

#include "SDL.h"

int
main(int argc, char **argv)
{
    Uint32 format = SDL_PIXELFORMAT_RGB888;
    Uint32 round_trip;
    Uint32 rmask, gmask, bmask, amask;
    int bpp;

    (void)argc;
    (void)argv;
    if (!SDL_PixelFormatEnumToMasks(format, &bpp, &rmask, &gmask, &bmask, &amask)) {
        fprintf(stderr, "SDL_PixelFormatEnumToMasks failed: %s\n", SDL_GetError());
        return 1;
    }
    round_trip = SDL_MasksToPixelFormatEnum(bpp, rmask, gmask, bmask, amask);
    printf("RGB888 bpp=%d masks=%08lx/%08lx/%08lx/%08lx roundtrip=%08lx\n",
           bpp, (unsigned long)rmask, (unsigned long)gmask,
           (unsigned long)bmask, (unsigned long)amask,
           (unsigned long)round_trip);
    if (round_trip != format) {
        fprintf(stderr, "SDL pixel-format round trip failed: %s\n", SDL_GetError());
        return 1;
    }
    printf("openstep-sdl-pixel-format-smoke: PASS\n");
    return 0;
}
