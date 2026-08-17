/* Standard SDL2 AppKit-window lifecycle smoke for OPENSTEP.
   Run only from a console Workspace terminal. */
#include <stdio.h>

#include "SDL.h"

static void
checkpoint(const char *name)
{
    fprintf(stderr, "openstep-sdl-window-lifecycle-smoke: %s\n", name);
    fflush(stderr);
}

static SDL_Surface *
window_surface_checkpoint(SDL_Window *window, const char *name)
{
    SDL_Surface *surface;

    checkpoint(name);
    surface = SDL_GetWindowSurface(window);
    if (!surface) {
        fprintf(stderr, "openstep SDL window surface failed at %s: %s\n",
                name, SDL_GetError());
    }
    return surface;
}

int
main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Surface *surface;
    SDL_Rect dirty;
    int w, h, x, y;
    int top, left, bottom, right;

    (void)argc;
    (void)argv;
    checkpoint("SDL_Init(SDL_INIT_VIDEO)");
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }
    checkpoint("create resizable hidden window");
    window = SDL_CreateWindow("SDL OpenStep lifecycle smoke",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              64, 48, SDL_WINDOW_HIDDEN | SDL_WINDOW_RESIZABLE);
    if (!window) {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }
    checkpoint("position size limits and borders");
    SDL_SetWindowMinimumSize(window, 48, 32);
    SDL_SetWindowMaximumSize(window, 128, 96);
    SDL_SetWindowSize(window, 80, 60);
    SDL_GetWindowSize(window, &w, &h);
    if (w != 80 || h != 60) goto failed;
    SDL_SetWindowPosition(window, 24, 24);
    SDL_GetWindowPosition(window, &x, &y);
    if (x != 24 || y != 24 ||
        SDL_GetWindowBordersSize(window, &top, &left, &bottom, &right) != 0 ||
        top < 0 || left < 0 || bottom < 0 || right < 0) goto failed;
    surface = window_surface_checkpoint(window, "initial window surface");
    if (!surface) goto failed;
    checkpoint("border and resizable style transitions");
    SDL_SetWindowResizable(window, SDL_FALSE);
    surface = window_surface_checkpoint(window, "surface after disable resizable");
    if (!surface) goto failed;
    SDL_SetWindowResizable(window, SDL_TRUE);
    surface = window_surface_checkpoint(window, "surface after enable resizable");
    if (!surface) goto failed;
    SDL_SetWindowBordered(window, SDL_FALSE);
    surface = window_surface_checkpoint(window, "surface after remove border");
    if (!surface) goto failed;
    if (SDL_GetWindowBordersSize(window, &top, &left, &bottom, &right) != 0 ||
        top != 0 || left != 0 || bottom != 0 || right != 0) goto failed;
    SDL_SetWindowBordered(window, SDL_TRUE);
    surface = window_surface_checkpoint(window, "surface after restore border");
    if (!surface) goto failed;
    checkpoint("window surface partial presentation");
    if (SDL_FillRect(surface, NULL, SDL_MapRGB(surface->format, 0x11, 0x22, 0x33)) != 0) goto failed;
    dirty.x = 8;
    dirty.y = 7;
    dirty.w = 20;
    dirty.h = 16;
    if (SDL_FillRect(surface, &dirty, SDL_MapRGB(surface->format, 0x88, 0x44, 0x22)) != 0 ||
        SDL_UpdateWindowSurfaceRects(window, &dirty, 1) != 0) goto failed;
    checkpoint("show hide raise and top-level ordering");
    SDL_ShowWindow(window);
    SDL_PumpEvents();
    SDL_SetWindowAlwaysOnTop(window, SDL_TRUE);
    SDL_RaiseWindow(window);
    SDL_SetWindowAlwaysOnTop(window, SDL_FALSE);
    SDL_HideWindow(window);
    SDL_ShowWindow(window);
    SDL_PumpEvents();
    checkpoint("minimize restore and teardown");
    SDL_MaximizeWindow(window);
    SDL_PumpEvents();
    if (!(SDL_GetWindowFlags(window) & SDL_WINDOW_MAXIMIZED)) goto failed;
    SDL_RestoreWindow(window);
    SDL_PumpEvents();
    if (SDL_GetWindowFlags(window) & SDL_WINDOW_MAXIMIZED) goto failed;
    SDL_MinimizeWindow(window);
    SDL_Delay(50);
    SDL_PumpEvents();
    SDL_RestoreWindow(window);
    if (SDL_SetWindowOpacity(window, 0.5f) != -1) goto failed;
    SDL_ClearError();
    SDL_DestroyWindow(window);
    SDL_Quit();
    printf("openstep-sdl-window-lifecycle-smoke: PASS\n");
    return 0;

failed:
    fprintf(stderr, "openstep SDL window lifecycle failed: %s\n", SDL_GetError());
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
}
