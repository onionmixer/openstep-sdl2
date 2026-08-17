/* Standard SDL2 desktop-fullscreen transition smoke for the OPENSTEP console. */
#include <stdio.h>

#include "SDL.h"

static void
checkpoint(const char *name)
{
    fprintf(stderr, "openstep-sdl-fullscreen-smoke: %s\n", name);
    fflush(stderr);
}

static int
require_surface(SDL_Window *window, const char *name)
{
    if (!SDL_GetWindowSurface(window)) {
        fprintf(stderr, "openstep-sdl-fullscreen-smoke: %s surface failed: %s\n",
                name, SDL_GetError());
        return -1;
    }
    /* A failed optional accelerated-framebuffer attempt is allowed before
       the OpenStep software framebuffer succeeds; do not report it later. */
    SDL_ClearError();
    return 0;
}

int
main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_DisplayMode desktop;
    int w, h;

    (void)argc;
    (void)argv;
    checkpoint("SDL_Init(SDL_INIT_VIDEO)");
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "fullscreen smoke init failed: %s\n", SDL_GetError());
        return 1;
    }
    if (SDL_GetDesktopDisplayMode(0, &desktop) != 0) {
        fprintf(stderr, "desktop mode failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }
    checkpoint("create windowed 96x72 window");
    window = SDL_CreateWindow("SDL OpenStep fullscreen smoke", 40, 40, 96, 72,
                              SDL_WINDOW_RESIZABLE);
    if (!window) {
        fprintf(stderr, "fullscreen smoke window failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }
    if (require_surface(window, "windowed") < 0) goto failed;
    checkpoint("enter desktop fullscreen");
    if (SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP) != 0) {
        fprintf(stderr, "openstep-sdl-fullscreen-smoke: enter failed: %s\n", SDL_GetError());
        goto failed;
    }
    SDL_PumpEvents();
    SDL_GetWindowSize(window, &w, &h);
    fprintf(stderr, "openstep-sdl-fullscreen-smoke: entered flags=0x%08lx size=%dx%d desktop=%dx%d\n",
            (unsigned long)SDL_GetWindowFlags(window), w, h, desktop.w, desktop.h);
    if ((SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN_DESKTOP) != SDL_WINDOW_FULLSCREEN_DESKTOP ||
        w != desktop.w || h != desktop.h || require_surface(window, "fullscreen") < 0) goto failed;
    checkpoint("leave desktop fullscreen");
    if (SDL_SetWindowFullscreen(window, 0) != 0) {
        fprintf(stderr, "openstep-sdl-fullscreen-smoke: leave failed: %s\n", SDL_GetError());
        goto failed;
    }
    SDL_PumpEvents();
    SDL_GetWindowSize(window, &w, &h);
    fprintf(stderr, "openstep-sdl-fullscreen-smoke: restored flags=0x%08lx size=%dx%d\n",
            (unsigned long)SDL_GetWindowFlags(window), w, h);
    if ((SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN) ||
        w != 96 || h != 72 || require_surface(window, "restored") < 0) goto failed;
    SDL_DestroyWindow(window);
    window = NULL;
    checkpoint("create initial desktop fullscreen 88x64 window");
    window = SDL_CreateWindow("SDL OpenStep initial fullscreen smoke", 60, 60, 88, 64,
                              SDL_WINDOW_FULLSCREEN_DESKTOP);
    if (!window) goto failed;
    SDL_GetWindowSize(window, &w, &h);
    fprintf(stderr, "openstep-sdl-fullscreen-smoke: initial flags=0x%08lx size=%dx%d desktop=%dx%d\n",
            (unsigned long)SDL_GetWindowFlags(window), w, h, desktop.w, desktop.h);
    if ((SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN_DESKTOP) != SDL_WINDOW_FULLSCREEN_DESKTOP ||
        w != desktop.w || h != desktop.h || require_surface(window, "initial fullscreen") < 0) goto failed;
    checkpoint("leave initial desktop fullscreen");
    if (SDL_SetWindowFullscreen(window, 0) != 0) {
        fprintf(stderr, "openstep-sdl-fullscreen-smoke: initial leave failed: %s\n", SDL_GetError());
        goto failed;
    }
    SDL_PumpEvents();
    SDL_GetWindowSize(window, &w, &h);
    fprintf(stderr, "openstep-sdl-fullscreen-smoke: initial restored flags=0x%08lx size=%dx%d\n",
            (unsigned long)SDL_GetWindowFlags(window), w, h);
    if ((SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN) ||
        w != 88 || h != 64 || require_surface(window, "initial restored") < 0) goto failed;
    SDL_DestroyWindow(window);
    SDL_Quit();
    printf("openstep-sdl-fullscreen-smoke: PASS desktop=%dx%d\n", desktop.w, desktop.h);
    return 0;

failed:
    fprintf(stderr, "openstep SDL fullscreen smoke failed: %s\n", SDL_GetError());
    if (window) SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
}
