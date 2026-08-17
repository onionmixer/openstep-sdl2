#include <sys/time.h>

#include "SDL_atomic.h"
#include "thread/SDL_thread_c.h"
#include "timer/SDL_timer_c.h"

extern Uint64 SDL_OPENSTEP_TimevalDeltaMicroseconds(const struct timeval *origin,
                                                    const struct timeval *sample);

static SDL_atomic_t callback_count;

/* Keep SDL_thread.c's dependency on SDL.c limited to the available core body. */
void SDL_InitMainThread(void)
{
    SDL_InitTLSData();
}

static Uint32 SDLCALL timer_callback(Uint32 interval, void *userdata)
{
    (void)interval;
    (void)userdata;
    SDL_AtomicIncRef(&callback_count);
    return 0;
}

int main(void)
{
    struct timeval origin;
    struct timeval sample;
    Uint64 ticks_before;
    Uint64 ticks_after;
    Uint64 counter_before;
    Uint64 counter_after;
    SDL_TimerID timer;
    int tries;

    origin.tv_sec = 10;
    origin.tv_usec = 900000;
    sample.tv_sec = 11;
    sample.tv_usec = 100000;
    if (SDL_OPENSTEP_TimevalDeltaMicroseconds(&origin, &sample) != 200000U) {
        return 1;
    }
    sample.tv_sec = 9;
    sample.tv_usec = 999999;
    if (SDL_OPENSTEP_TimevalDeltaMicroseconds(&origin, &sample) != 0) {
        return 2;
    }

    SDL_TicksInit();
    ticks_before = SDL_GetTicks64();
    counter_before = SDL_GetPerformanceCounter();
    SDL_Delay(20);
    ticks_after = SDL_GetTicks64();
    counter_after = SDL_GetPerformanceCounter();
    if ((ticks_after < ticks_before) || (ticks_after - ticks_before < 10) ||
        (counter_after < counter_before) ||
        (SDL_GetPerformanceFrequency() != 1000000U)) {
        return 3;
    }
    if ((Sint32)(SDL_GetTicks() - (Uint32)ticks_before) < 10) {
        return 4;
    }

    if (SDL_TimerInit() != 0) {
        return 5;
    }
    timer = SDL_AddTimer(10, timer_callback, NULL);
    if (!timer) {
        SDL_TimerQuit();
        return 6;
    }
    for (tries = 0; tries < 100 && SDL_AtomicGet(&callback_count) == 0; ++tries) {
        SDL_Delay(5);
    }
    SDL_TimerQuit();
    if (SDL_AtomicGet(&callback_count) != 1) {
        return 7;
    }

    SDL_TicksQuit();
    if (SDL_GetTicks64() > 1) {
        return 8;
    }
    return 0;
}
