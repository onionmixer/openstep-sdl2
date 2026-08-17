/* SDL 2.32 has no SDL_SYSWM_OPENSTEP ABI member. Verify the regular public
   API remains callable and returns its documented unknown/unsupported result
   instead of exposing an invented private native-handle structure. */
#include "SDL.h"
#include "SDL_syswm.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(void)
{
    SDL_Window *window;
    SDL_SysWMinfo info;
    int result = 0;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 OPENSTEP syswm smoke",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              80, 60, SDL_WINDOW_HIDDEN);
    if (!window) {
        SDL_Quit();
        return 2;
    }
    SDL_zero(info);
    SDL_VERSION(&info.version);
    if (SDL_GetWindowWMInfo(window, &info) != SDL_FALSE) {
        result = 3;
    } else if (info.subsystem != SDL_SYSWM_UNKNOWN) {
        result = 4;
    } else if (SDL_GetError()[0] == '\0') {
        result = 5;
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (result) {
        fprintf(stderr, "openstep-sdl-syswm-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-syswm-smoke: PASS unknown/unsupported SDL_SYSWM result\n");
    return 0;
}
