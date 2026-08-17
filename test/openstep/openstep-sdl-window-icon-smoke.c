/* Standard SDL2 window-icon lifecycle smoke for the OPENSTEP AppKit backend.
   The final visual/dock assertion requires a real Workspace session; this
   test intentionally uses only public SDL APIs. */
#include <stdio.h>

#include "SDL.h"

static int fail(const char *what)
{
    fprintf(stderr, "openstep-sdl-window-icon-smoke: %s: %s\n", what, SDL_GetError());
    return 1;
}

static SDL_Surface *make_icon(Uint8 red, Uint8 green, Uint8 blue)
{
    SDL_Surface *icon;
    Uint32 outer;
    Uint32 inner;
    SDL_Rect rect;

    icon = SDL_CreateRGBSurfaceWithFormat(0, 24, 24, 32, SDL_PIXELFORMAT_ARGB8888);
    if (!icon) return NULL;
    outer = SDL_MapRGBA(icon->format, red, green, blue, 255);
    inner = SDL_MapRGBA(icon->format, 255, 255, 255, 255);
    if (SDL_FillRect(icon, NULL, outer) < 0) {
        SDL_FreeSurface(icon);
        return NULL;
    }
    rect.x = 6;
    rect.y = 6;
    rect.w = 12;
    rect.h = 12;
    if (SDL_FillRect(icon, &rect, inner) < 0) {
        SDL_FreeSurface(icon);
        return NULL;
    }
    return icon;
}

int main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Surface *first;
    SDL_Surface *second;

    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    window = SDL_CreateWindow("SDL OpenStep icon smoke", 44, 44, 120, 80, 0);
    if (!window) {
        SDL_Quit();
        return fail("window creation failed");
    }
    first = make_icon(0x20, 0x70, 0xd0);
    second = make_icon(0xd0, 0x50, 0x20);
    if (!first || !second) {
        if (first) SDL_FreeSurface(first);
        if (second) SDL_FreeSurface(second);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("icon surface creation failed");
    }
    /* SDL copies and normalizes each source surface before calling the
       backend, so both input surfaces may be released immediately. */
    SDL_SetWindowIcon(window, first);
    SDL_FreeSurface(first);
    SDL_SetWindowIcon(window, second);
    SDL_FreeSurface(second);
    /* Keep the second (orange) application/dock icon visible long enough for
       a physical Workspace observation.  This still requires no interaction
       and automatically tears down afterwards. */
    SDL_PumpEvents();
    SDL_Delay(45000);
    SDL_DestroyWindow(window);
    SDL_Quit();
    printf("openstep-sdl-window-icon-smoke: PASS two standard icon updates\n");
    return 0;
}
