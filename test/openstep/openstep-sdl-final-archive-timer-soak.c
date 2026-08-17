/*
 * One-minute public SDL timer soak through final libSDL2.a.
 *
 * This deliberately runs outside the short regression runner: it checks that
 * a repeating callback remains live over time and that SDL_RemoveTimer()
 * stops it before SDL_Quit().
 */
#include <stdio.h>

#include "SDL.h"
#include "SDL_atomic.h"

#define SOAK_MILLISECONDS 60000
#define TIMER_INTERVAL 10
#define MINIMUM_CALLBACKS 100

static SDL_atomic_t callback_count;

static Uint32 SDLCALL TimerCallback(Uint32 interval, void *userdata)
{
    (void)userdata;
    SDL_AtomicIncRef(&callback_count);
    return interval;
}

int main(void)
{
    SDL_TimerID timer;
    Uint32 deadline;
    int before_remove;
    int after_remove;

    if (SDL_Init(SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "timer-soak: init failed: %s\n", SDL_GetError());
        return 1;
    }
    timer = SDL_AddTimer(TIMER_INTERVAL, TimerCallback, NULL);
    if (timer == 0) {
        fprintf(stderr, "timer-soak: add failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 2;
    }
    deadline = SDL_GetTicks() + SOAK_MILLISECONDS;
    while ((Sint32)(deadline - SDL_GetTicks()) > 0) {
        SDL_Delay(20);
    }
    before_remove = SDL_AtomicGet(&callback_count);
    if (before_remove < MINIMUM_CALLBACKS) {
        fprintf(stderr, "timer-soak: only %d callbacks\n", before_remove);
        SDL_RemoveTimer(timer);
        SDL_Quit();
        return 3;
    }
    if (!SDL_RemoveTimer(timer)) {
        fprintf(stderr, "timer-soak: remove failed\n");
        SDL_Quit();
        return 4;
    }
    SDL_Delay(100);
    after_remove = SDL_AtomicGet(&callback_count);
    SDL_Quit();
    if (after_remove != before_remove) {
        fprintf(stderr, "timer-soak: callbacks continued after remove (%d -> %d)\n",
                before_remove, after_remove);
        return 5;
    }
    printf("openstep-sdl-final-archive-timer-soak: PASS callbacks=%d duration=%dms\n",
           before_remove, SOAK_MILLISECONDS);
    return 0;
}
