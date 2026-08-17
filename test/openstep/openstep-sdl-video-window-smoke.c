#include "SDL.h"
#include "SDL_surface.h"
#include "SDL_video.h"
#include "SDL_internal.h"

int main(void)
{
    SDL_DisplayMode mode;
    SDL_Window *window;
    SDL_Surface *surface;
    Uint32 color;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        return 1;
    }
    if (SDL_GetCurrentVideoDriver() == NULL ||
        SDL_strcmp(SDL_GetCurrentVideoDriver(), "openstep") != 0) {
        SDL_Quit();
        return 2;
    }
    if (SDL_GetNumVideoDisplays() < 1 ||
        SDL_GetDesktopDisplayMode(0, &mode) != 0 || mode.w <= 0 || mode.h <= 0) {
        SDL_Quit();
        return 3;
    }
    window = SDL_CreateWindow("SDL2 OPENSTEP private smoke",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              32, 24, SDL_WINDOW_HIDDEN);
    if (window == NULL) {
        SDL_Quit();
        return 4;
    }
    SDL_SetWindowTitle(window, "SDL2 OPENSTEP private smoke title");
    if (SDL_GetWindowTitle(window) == NULL ||
        SDL_strcmp(SDL_GetWindowTitle(window), "SDL2 OPENSTEP private smoke title") != 0) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 5;
    }
    surface = SDL_GetWindowSurface(window);
    if (surface == NULL) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 6;
    }
    color = SDL_MapRGBA(surface->format, 0x21, 0x43, 0x65, 0xff);
    if (SDL_FillRect(surface, NULL, color) != 0 ||
        SDL_UpdateWindowSurface(window) != 0) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 7;
    }
    SDL_PumpEvents();
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
