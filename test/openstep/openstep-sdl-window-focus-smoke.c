/* Standard SDL2 window input-focus smoke for the OPENSTEP console. */
#include <stdio.h>

#include "SDL.h"

static int
focus_window(SDL_Window *window, const char *name)
{
    SDL_SetWindowInputFocus(window);
    SDL_Delay(20);
    SDL_PumpEvents();
    if (SDL_GetKeyboardFocus() != window) {
        fprintf(stderr, "%s did not receive SDL keyboard focus\n", name);
        return -1;
    }
    if (SDL_GetMouseFocus() != window) {
        fprintf(stderr, "%s did not retain SDL mouse focus\n", name);
        return -1;
    }
    return 0;
}

int
main(int argc, char **argv)
{
    SDL_Window *first;
    SDL_Window *second;

    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "focus smoke init failed: %s\n", SDL_GetError());
        return 1;
    }
    first = SDL_CreateWindow("SDL OpenStep focus A", 40, 40, 180, 96, 0);
    second = SDL_CreateWindow("SDL OpenStep focus B", 250, 40, 180, 96, 0);
    if (!first || !second) {
        fprintf(stderr, "focus smoke window failed: %s\n", SDL_GetError());
        if (second) SDL_DestroyWindow(second);
        if (first) SDL_DestroyWindow(first);
        SDL_Quit();
        return 1;
    }
    if (focus_window(first, "first window") < 0 ||
        focus_window(second, "second window") < 0 ||
        focus_window(first, "first window again") < 0) {
        SDL_DestroyWindow(second);
        SDL_DestroyWindow(first);
        SDL_Quit();
        return 1;
    }
    SDL_DestroyWindow(second);
    SDL_DestroyWindow(first);
    SDL_Quit();
    printf("openstep-sdl-window-focus-smoke: PASS\n");
    return 0;
}
