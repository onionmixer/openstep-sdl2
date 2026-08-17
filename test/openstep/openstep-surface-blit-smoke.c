#include "SDL_surface.h"
#include "thread/SDL_thread_c.h"

void SDL_InitMainThread(void)
{
    SDL_InitTLSData();
}

int main(void)
{
    SDL_Surface *source;
    SDL_Surface *destination;
    Uint32 color;
    Uint32 *pixels;
    Uint8 rgb565[2];

    source = SDL_CreateRGBSurfaceWithFormat(0, 2, 2, 32, SDL_PIXELFORMAT_ARGB8888);
    destination = SDL_CreateRGBSurfaceWithFormat(0, 2, 2, 32, SDL_PIXELFORMAT_ARGB8888);
    if (!source || !destination) {
        SDL_FreeSurface(source);
        SDL_FreeSurface(destination);
        return 1;
    }
    color = SDL_MapRGBA(source->format, 0x21, 0x53, 0x87, 0xff);
    if (SDL_FillRect(source, NULL, color) != 0 ||
        SDL_BlitSurface(source, NULL, destination, NULL) != 0) {
        SDL_FreeSurface(source);
        SDL_FreeSurface(destination);
        return 2;
    }
    pixels = (Uint32 *)destination->pixels;
    if (pixels[0] != color || pixels[3] != color) {
        SDL_FreeSurface(source);
        SDL_FreeSurface(destination);
        return 3;
    }
    if (SDL_ConvertPixels(1, 1, SDL_PIXELFORMAT_ARGB8888, pixels,
                          destination->pitch, SDL_PIXELFORMAT_RGB565,
                          rgb565, 2) != 0) {
        SDL_FreeSurface(source);
        SDL_FreeSurface(destination);
        return 4;
    }
    SDL_FreeSurface(source);
    SDL_FreeSurface(destination);
    return 0;
}
