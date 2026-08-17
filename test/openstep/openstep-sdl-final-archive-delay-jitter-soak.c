/* Bounded measurement of SDL_Delay(1) scheduling through final libSDL2.a.
   A historical scheduler can oversleep, but ticks must never regress and the
   observed granularity distribution must be retained. */
#include <stdio.h>

#include "SDL.h"

#define SAMPLE_COUNT 250

int
main(int argc, char **argv)
{
    int i;
    Uint64 before;
    Uint64 after;
    Uint64 elapsed;
    Uint64 maximum = 0;
    int above_10 = 0;
    int above_25 = 0;
    int above_100 = 0;

    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_TIMER) != 0) {
        fprintf(stderr, "delay-jitter-soak: init: %s\n", SDL_GetError());
        return 1;
    }
    for (i = 0; i < SAMPLE_COUNT; ++i) {
        before = SDL_GetTicks64();
        SDL_Delay(1);
        after = SDL_GetTicks64();
        if (after < before) {
            fprintf(stderr, "delay-jitter-soak: tick regression at sample %d\n", i);
            SDL_Quit();
            return 2;
        }
        elapsed = after - before;
        if (elapsed > maximum) maximum = elapsed;
        if (elapsed > 10) ++above_10;
        if (elapsed > 25) ++above_25;
        if (elapsed > 100) ++above_100;
        if ((i + 1) % 250 == 0) {
            printf("delay-jitter-soak: progress=%d max=%lu over100=%d\n",
                   i + 1, (unsigned long)maximum, above_100);
            fflush(stdout);
        }
    }
    printf("delay-jitter-soak: PASS samples=%d max=%lu over10=%d over25=%d over100=%d\n",
           SAMPLE_COUNT, (unsigned long)maximum, above_10, above_25,
           above_100);
    SDL_Quit();
    return 0;
}
