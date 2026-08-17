#include "SDL.h"
#include "SDL_timer.h"
#include "SDL_video.h"
#include "SDL_internal.h"

int main(void)
{
    Uint32 before;
    Uint32 after;

    /* SDL.c exposes this private initialization boundary for the real main
       wrapper/thread path. Invoke it here so the dispatcher and timer are
       tested with their actual TLS, ticks and log setup. */
    SDL_SetMainReady();
    SDL_InitMainThread();

    if (SDL_Init(SDL_INIT_TIMER) != 0) {
        return 1;
    }
    if ((SDL_WasInit(SDL_INIT_TIMER) & SDL_INIT_TIMER) == 0) {
        SDL_Quit();
        return 2;
    }

    before = SDL_GetTicks();
    SDL_Delay(10);
    after = SDL_GetTicks();
    if (after < before + 5) {
        SDL_Quit();
        return 3;
    }

    SDL_Quit();
    return 0;
}
