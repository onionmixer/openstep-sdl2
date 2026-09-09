/* OPENSTEP 4.2 gettimeofday/select timer backend for the SDL2 core subset. */
#include "../SDL_internal.h"

#include <errno.h>
#include <libc.h>
#include <sys/time.h>
#include <mach/cthreads.h>

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

    /*
     * SDL_Delay(0) MUST NOT TOUCH THE TIMER.
     *
     * The core's spinlock (src/atomic/SDL_spinlock.c) spins 32 times and
     * then calls SDL_Delay(0) to give up the processor.  This function
     * used to begin with SDL_GetTicks64(), which takes openstep_ticks_lock
     * -- an SDL spinlock -- and with milliseconds == 0 the loop below
     * exits before ever reaching select().  So a thread spinning on the
     * ticks lock itself (SDL_GetPerformanceCounter is that lock, and the
     * audio backend reads it four times a buffer) fell back into
     * SDL_Delay(0), took the same lock again, spun, fell back again: a
     * recursion that never yields, a few hundred frames deep in under a
     * millisecond, until the stack is gone.  It needs only the lock's
     * holder to be preempted inside its few-instruction critical section,
     * and a boosted audio thread preempts the main thread at whatever
     * instruction it happens to be on.
     *
     * cthread_yield() is swtch_pri(0): the calling thread is depressed and
     * the processor is handed to whoever is runnable -- the holder
     * included, whatever its priority.  That is the one thing a spinlock
     * fallback has to do, and it is the thing the old path never did.
     */
    if (milliseconds == 0) {
        cthread_yield();
        return;
    }

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
