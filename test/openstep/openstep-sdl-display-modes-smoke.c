/* Standard SDL2 display enumeration smoke for the OPENSTEP desktop-mode
   backend. It does not request unsupported display-mode switching. */
#include <stdio.h>

#include "SDL.h"

static int fail(const char *what)
{
    fprintf(stderr, "openstep-sdl-display-modes-smoke: %s: %s\n", what, SDL_GetError());
    return 1;
}

int main(int argc, char **argv)
{
    SDL_Rect bounds;
    SDL_DisplayMode desktop;
    SDL_DisplayMode current;
    SDL_DisplayMode listed;
    SDL_DisplayMode wanted;
    SDL_DisplayMode closest;
    const char *name;
    int displays;
    int modes;

    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    displays = SDL_GetNumVideoDisplays();
    if (displays != 1) {
        SDL_Quit();
        return fail("expected exactly one OPENSTEP main display");
    }
    name = SDL_GetDisplayName(0);
    if (!name || SDL_strcmp(name, "OPENSTEP Main Display") != 0) {
        SDL_Quit();
        return fail("unexpected primary display name");
    }
    if (SDL_GetDisplayBounds(0, &bounds) != 0 || bounds.w <= 0 || bounds.h <= 0) {
        SDL_Quit();
        return fail("invalid display bounds");
    }
    if (SDL_GetDesktopDisplayMode(0, &desktop) != 0 ||
        SDL_GetCurrentDisplayMode(0, &current) != 0 ||
        desktop.w != bounds.w || desktop.h != bounds.h ||
        current.w != desktop.w || current.h != desktop.h) {
        SDL_Quit();
        return fail("desktop/current mode mismatch");
    }
    modes = SDL_GetNumDisplayModes(0);
    if (modes != 1) {
        SDL_Quit();
        return fail("expected one enumerable desktop mode");
    }
    if (SDL_GetDisplayMode(0, 0, &listed) != 0 ||
        listed.w != desktop.w || listed.h != desktop.h ||
        listed.format != desktop.format || listed.refresh_rate != desktop.refresh_rate) {
        SDL_Quit();
        return fail("enumerated mode differs from desktop mode");
    }
    wanted = desktop;
    if (!SDL_GetClosestDisplayMode(0, &wanted, &closest) ||
        closest.w != desktop.w || closest.h != desktop.h ||
        closest.format != desktop.format) {
        SDL_Quit();
        return fail("desktop mode was not selected as closest mode");
    }
    SDL_Quit();
    printf("openstep-sdl-display-modes-smoke: PASS one desktop mode %dx%d\n",
           desktop.w, desktop.h);
    return 0;
}
