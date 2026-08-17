/* Verify a native message box remains callable with a real SDL parent window. */
#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(void)
{
    SDL_Window *window;

    if (!freopen("/tmp/SDL20/log/openstep-sdl-parent-messagebox-probe.log", "w", stdout)) {
        return 4;
    }
    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 OPENSTEP message-box parent",
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              300, 120, 0);
    if (!window) {
        SDL_Quit();
        return 2;
    }
    printf("openstep-sdl-parent-messagebox-probe: waiting for OK\n");
    fflush(stdout);
    if (SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_INFORMATION,
                                 "SDL2 OPENSTEP parent message box",
                                 "Select OK; an SDL parent window is behind this panel.",
                                 window) != 0) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 3;
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    printf("openstep-sdl-parent-messagebox-probe: PASS\n");
    return 0;
}
