/* Exercise public SDL timer-thread callbacks through the final archive. */
#include <stdio.h>

#include "SDL.h"
#include "SDL_atomic.h"

static SDL_atomic_t callback_count;

static Uint32 SDLCALL timer_callback(Uint32 interval, void *userdata)
{
    (void)interval;
    (void)userdata;
    SDL_AtomicIncRef(&callback_count);
    return 0;
}

int main(void)
{
    SDL_TimerID timer;
    int tries;

    if (SDL_Init(SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "timer-callback-smoke: init: %s\n", SDL_GetError());
        return 1;
    }
    timer = SDL_AddTimer(10, timer_callback, NULL);
    if (!timer) {
        SDL_Quit();
        return 2;
    }
    for (tries = 0; tries < 100 && SDL_AtomicGet(&callback_count) == 0; ++tries) {
        SDL_Delay(5);
    }
    SDL_Quit();
    if (SDL_AtomicGet(&callback_count) != 1) return 3;

    printf("openstep-sdl-final-archive-timer-callback-smoke: PASS callback\n");
    return 0;
}
