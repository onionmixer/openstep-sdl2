/* Physical SDL2 desktop-fullscreen and window-surface presentation probe. */
#include <stdio.h>

#include "SDL.h"

static int Present(SDL_Window *window, Uint8 red, Uint8 green, Uint8 blue)
{
    SDL_Surface *surface = SDL_GetWindowSurface(window);
    Uint32 pixel;

    if (surface == NULL) return -1;
    pixel = SDL_MapRGBA(surface->format, red, green, blue, 255);
    if (SDL_FillRect(surface, NULL, pixel) != 0) return -1;
    return SDL_UpdateWindowSurface(window);
}

static void PumpFor(Uint32 milliseconds)
{
    Uint32 deadline = SDL_GetTicks() + milliseconds;

    while ((Sint32)(deadline - SDL_GetTicks()) > 0) {
        SDL_PumpEvents();
        SDL_Delay(10);
    }
}

static int Fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-physical-fullscreen-probe: %s: %s\n",
            what, SDL_GetError());
    fflush(stdout);
    return 1;
}

int main(int argc, char **argv)
{
    SDL_Window *window = NULL;
    int result = 0;

    (void)argc;
    (void)argv;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-physical-fullscreen.log", "w", stdout)) {
        return 2;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return Fail("video init failed");
    window = SDL_CreateWindow("SDL2 fullscreen physical probe",
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              480, 240, SDL_WINDOW_RESIZABLE);
    if (window == NULL) {
        result = Fail("window creation failed");
        goto done;
    }
    if (Present(window, 190, 45, 45) != 0) {
        result = Fail("red window presentation failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-physical-fullscreen-probe: RED window 3sec\n");
    fflush(stdout);
    PumpFor(3000);
    if (SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP) != 0) {
        result = Fail("enter desktop fullscreen failed");
        goto done;
    }
    if (Present(window, 35, 70, 190) != 0) {
        result = Fail("blue fullscreen presentation failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-physical-fullscreen-probe: BLUE fullscreen 15sec\n");
    fflush(stdout);
    PumpFor(15000);
    if (SDL_SetWindowFullscreen(window, 0) != 0) {
        result = Fail("leave desktop fullscreen failed");
        goto done;
    }
    if (Present(window, 190, 45, 45) != 0) {
        result = Fail("red restored-window presentation failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-physical-fullscreen-probe: RED restored 3sec\n");
    fflush(stdout);
    PumpFor(3000);

done:
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result == 0) {
        fprintf(stdout, "openstep-sdl-physical-fullscreen-probe: PASS window/fullscreen/restore\n");
    }
    fflush(stdout);
    return result;
}
