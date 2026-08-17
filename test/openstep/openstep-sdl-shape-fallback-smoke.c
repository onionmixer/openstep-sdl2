/* Verify the standard SDL2 shaped-window API remains linkable on OPENSTEP
   and returns SDL's documented nonshapeable result without a private mask API. */
#include <stdio.h>

#include "SDL.h"

static int fail(const char *what)
{
    fprintf(stderr, "openstep-sdl-shape-fallback-smoke: %s: %s\n", what, SDL_GetError());
    return 1;
}

int main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Window *shaped;
    SDL_Surface *shape;
    SDL_WindowShapeMode mode;
    int result = 0;

    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    window = SDL_CreateWindow("SDL OpenStep shape fallback", 20, 20, 48, 48,
                              SDL_WINDOW_HIDDEN);
    if (!window) {
        SDL_Quit();
        return fail("normal window creation failed");
    }
    shape = SDL_CreateRGBSurfaceWithFormat(0, 2, 2, 32, SDL_PIXELFORMAT_ARGB8888);
    if (!shape) result = 1;
    SDL_zero(mode);
    mode.mode = ShapeModeDefault;
    if (!result && SDL_IsShapedWindow(window)) result = 2;
    if (!result && SDL_SetWindowShape(window, shape, &mode) != SDL_NONSHAPEABLE_WINDOW) result = 3;
    if (!result && SDL_GetShapedWindowMode(window, &mode) != SDL_NONSHAPEABLE_WINDOW) result = 4;
    shaped = result ? NULL : SDL_CreateShapedWindow("unsupported", 20, 20, 16, 16, 0);
    if (!result && shaped != NULL) {
        SDL_DestroyWindow(shaped);
        result = 5;
    }
    if (shape) SDL_FreeSurface(shape);
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (result) return fail("unexpected shaped-window result");
    printf("openstep-sdl-shape-fallback-smoke: PASS standard nonshapeable results\n");
    return 0;
}
