#include "SDL.h"
#include "SDL_pixels.h"
#include "SDL_internal.h"

int main(void)
{
    Uint8 iyuv[6];
    Uint32 argb[4];
    SDL_PixelFormat *format;
    Uint8 r;
    Uint8 g;
    Uint8 b;
    Uint8 a;

    iyuv[0] = 235;
    iyuv[1] = 235;
    iyuv[2] = 235;
    iyuv[3] = 235;
    iyuv[4] = 128;
    iyuv[5] = 128;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(0) != 0) {
        return 1;
    }
    if (SDL_ConvertPixels(2, 2, SDL_PIXELFORMAT_IYUV, iyuv, 2,
                          SDL_PIXELFORMAT_ARGB8888, argb, 2 * (int)sizeof(Uint32)) != 0) {
        SDL_Quit();
        return 2;
    }
    format = SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888);
    if (format == NULL) {
        SDL_Quit();
        return 3;
    }
    SDL_GetRGBA(argb[0], format, &r, &g, &b, &a);
    SDL_FreeFormat(format);
    if (r < 250 || g < 250 || b < 250 || a != 255) {
        SDL_Quit();
        return 4;
    }
    SDL_Quit();
    return 0;
}
