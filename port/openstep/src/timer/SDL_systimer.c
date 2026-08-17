/* OPENSTEP 4.2 gettimeofday/select timer backend for the SDL2 core subset. */
#include "../SDL_internal.h"

#include <errno.h>
#include <libc.h>
#include <sys/time.h>

#include "SDL_atomic.h"
#include "SDL_timer.h"

static SDL_SpinLock openstep_ticks_lock;
static SDL_bool openstep_ticks_started;
static struct timeval openstep_start_time;
static struct timeval openstep_last_time;

static int OpenStep_TimevalBefore(const struct timeval *left,
                                  const struct timeval *right)
{
    if (left->tv_sec != right->tv_sec) {
        return left->tv_sec < right->tv_sec;
    }
    return left->tv_usec < right->tv_usec;
}

/* Kept externally visible for target-side boundary and clock-regression tests. */
Uint64 SDL_OPENSTEP_TimevalDeltaMicroseconds(const struct timeval *origin,
                                             const struct timeval *sample)
{
    long seconds;
    long microseconds;
    Uint64 result;

    seconds = sample->tv_sec - origin->tv_sec;
    microseconds = sample->tv_usec - origin->tv_usec;
    if (microseconds < 0) {
        --seconds;
        microseconds += 1000000;
    }
    if (seconds < 0) {
        return 0;
    }
    result = (Uint64)seconds;
    result *= 1000000U;
    result += (Uint64)microseconds;
    return result;
}

static Uint64 OpenStep_GetElapsedMicroseconds(void)
{
    struct timeval now;
    Uint64 elapsed;

    gettimeofday(&now, (struct timezone *)0);
    SDL_AtomicLock(&openstep_ticks_lock);
    if (!openstep_ticks_started) {
        openstep_start_time = now;
        openstep_last_time = now;
        openstep_ticks_started = SDL_TRUE;
    } else if (OpenStep_TimevalBefore(&now, &openstep_last_time)) {
        /* gettimeofday is not monotonic; never let exposed ticks regress. */
        now = openstep_last_time;
    } else {
        openstep_last_time = now;
    }
    elapsed = SDL_OPENSTEP_TimevalDeltaMicroseconds(&openstep_start_time, &now);
    SDL_AtomicUnlock(&openstep_ticks_lock);
    return elapsed;
}

void SDL_TicksInit(void)
{
    struct timeval now;

    gettimeofday(&now, (struct timezone *)0);
    SDL_AtomicLock(&openstep_ticks_lock);
    if (!openstep_ticks_started) {
        openstep_start_time = now;
        openstep_last_time = now;
        openstep_ticks_started = SDL_TRUE;
    }
    SDL_AtomicUnlock(&openstep_ticks_lock);
}

void SDL_TicksQuit(void)
{
    SDL_AtomicLock(&openstep_ticks_lock);
    openstep_ticks_started = SDL_FALSE;
    SDL_AtomicUnlock(&openstep_ticks_lock);
}

Uint64 SDL_GetTicks64(void)
{
    return OpenStep_GetElapsedMicroseconds() / 1000U;
}

Uint64 SDL_GetPerformanceCounter(void)
{
    return OpenStep_GetElapsedMicroseconds();
}

Uint64 SDL_GetPerformanceFrequency(void)
{
    return 1000000U;
}

void SDL_Delay(Uint32 milliseconds)
{
    struct timeval delay;
    Uint64 then;
    Uint64 now;
    Uint64 elapsed;
    int result;

    then = SDL_GetTicks64();
    do {
        now = SDL_GetTicks64();
        elapsed = now - then;
        then = now;
        if (elapsed >= (Uint64)milliseconds) {
            break;
        }
        milliseconds -= (Uint32)elapsed;
        delay.tv_sec = (long)(milliseconds / 1000U);
        delay.tv_usec = (long)((milliseconds % 1000U) * 1000U);
        result = select(0, 0, 0, 0, &delay);
    } while ((result < 0) && (errno == EINTR));
}
