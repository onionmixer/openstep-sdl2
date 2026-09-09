/* SDL2 mutexes over Mach cthreads, for OPENSTEP.
 *
 * WHY THIS IS NOT JUST mutex_lock().
 *
 * cthreads' mutex_lock() is mutex_try_lock() followed, on failure, by
 * mutex_wait_lock().  In this system's libsys, mutex_spin_limit is 0, so
 * mutex_wait_lock() takes no spins at all: it enters
 *
 *     while (1) { if (!m->lock && mutex_try_lock(m)) break; cthread_yield(); }
 *
 * and cthread_yield() is swtch_pri(0), which depresses the caller's
 * priority.  A thread that waits on a contended cthreads mutex therefore
 * loops for as long as the holder keeps it, lowering its own priority each
 * time round, and when the lock finally comes free it has to be scheduled
 * again from underneath everything else before it can take it.  For the
 * audio callback thread -- which SDL runs against a hardware deadline, and
 * whose lock is taken by the application's main thread on every frame -- that
 * is the difference between late and silent.
 *
 * NeXT documented the alternative rather than this one.  MachKit's NXLock:
 * "If a region of code is in use, an NXLock waits using the condition_wait()
 * function, so the thread doesn't busy-wait", and its unlock "using
 * condition_signal() to signal the next party that the lock is available".
 * That is what this file does, with the cthreads mutex demoted to a guard
 * held for a few instructions at a time.
 *
 * condition_wait() is not free of the same trick -- libsys's copy yields
 * condition_yield_limit (7) times before it blocks in msg_receive() -- but
 * seven is bounded and the loop above is not.
 *
 * Set SDL_OPENSTEP_MUTEX=yield to get the old behaviour back; that is the
 * control arm, and it exists so the two can be compared on one build.
 */
#include "../../SDL_internal.h"

#include <mach/cthreads.h>

#include "SDL_mutex.h"
#include "SDL_thread.h"
#include "SDL_timer.h"
#include "SDL_openstepmutex_c.h"

struct SDL_mutex
{
    /* In blocking mode `guard` protects the three fields below and is never
       held across a wait; in yield mode it *is* the lock and the fields are
       unused.  Either way SDL's own owner/recursion bookkeeping is the same. */
    mutex_t guard;
    condition_t avail;
    int held;
    SDL_threadID owner;
    int recursive;
};

/* -1 until the first mutex is created or locked. */
static int openstep_mutex_blocking = -1;

/* Written only by the watched thread, read only after it has stopped. */
static SDL_threadID openstep_watch_thread;
static Uint32 openstep_watch_acquires;
static Uint32 openstep_watch_us;
static Uint32 openstep_watch_max;

static int MutexBlocking(void)
{
    if (openstep_mutex_blocking < 0) {
        const char *s = SDL_getenv("SDL_OPENSTEP_MUTEX");
        openstep_mutex_blocking = (s != NULL && SDL_strcmp(s, "yield") == 0) ? 0 : 1;
    }
    return openstep_mutex_blocking;
}

int OPENSTEP_MutexIsBlocking(void)
{
    return MutexBlocking();
}

void OPENSTEP_MutexWatchThread(SDL_threadID id)
{
    openstep_watch_acquires = 0;
    openstep_watch_us = 0;
    openstep_watch_max = 0;
    openstep_watch_thread = id;
}

void OPENSTEP_MutexWatchStats(Uint32 *acquires, Uint32 *total_us, Uint32 *max_us)
{
    if (acquires) *acquires = openstep_watch_acquires;
    if (total_us) *total_us = openstep_watch_us;
    if (max_us)   *max_us   = openstep_watch_max;
}

SDL_mutex *SDL_CreateMutex(void)
{
    SDL_mutex *mutex;

    mutex = (SDL_mutex *)SDL_calloc(1, sizeof(*mutex));
    if (!mutex) {
        SDL_OutOfMemory();
        return NULL;
    }
    mutex->guard = mutex_alloc();
    if (!mutex->guard) {
        SDL_free(mutex);
        SDL_OutOfMemory();
        return NULL;
    }
    mutex_init(mutex->guard);
    mutex->avail = condition_alloc();
    if (!mutex->avail) {
        mutex_free(mutex->guard);
        SDL_free(mutex);
        SDL_OutOfMemory();
        return NULL;
    }
    condition_init(mutex->avail);
    return mutex;
}

void SDL_DestroyMutex(SDL_mutex *mutex)
{
    if (mutex) {
        if (mutex->avail) {
            condition_free(mutex->avail);
        }
        if (mutex->guard) {
            mutex_free(mutex->guard);
        }
        SDL_free(mutex);
    }
}

int SDL_LockMutex(SDL_mutex *mutex)
{
    SDL_threadID self;
    int watched;
    Uint32 t0 = 0;

    if (!mutex) {
        return SDL_SetError("Passed a NULL mutex");
    }
    self = SDL_ThreadID();
    if (mutex->owner == self) {
        ++mutex->recursive;
        return 0;
    }

    watched = (openstep_watch_thread != 0 && self == openstep_watch_thread);
    if (watched) {
        t0 = (Uint32)SDL_GetPerformanceCounter();
    }

    if (!MutexBlocking()) {
        mutex_lock(mutex->guard);
    } else {
        mutex_lock(mutex->guard);
        /* condition_wait() enqueues this thread before it drops the guard,
           so a signal taken under the guard cannot be lost; it can still
           return without the lock being free, hence the loop. */
        while (mutex->held) {
            condition_wait(mutex->avail, mutex->guard);
        }
        mutex->held = 1;
        mutex_unlock(mutex->guard);
    }

    if (watched) {
        Uint32 dt = (Uint32)SDL_GetPerformanceCounter() - t0;
        ++openstep_watch_acquires;
        openstep_watch_us += dt;
        if (dt > openstep_watch_max) {
            openstep_watch_max = dt;
        }
    }

    mutex->owner = self;
    mutex->recursive = 0;
    return 0;
}

int SDL_TryLockMutex(SDL_mutex *mutex)
{
    SDL_threadID self;

    if (!mutex) {
        return SDL_SetError("Passed a NULL mutex");
    }
    self = SDL_ThreadID();
    if (mutex->owner == self) {
        ++mutex->recursive;
        return 0;
    }

    if (!MutexBlocking()) {
        if (!mutex_try_lock(mutex->guard)) {
            return SDL_MUTEX_TIMEDOUT;
        }
    } else {
        /* Waiting for the guard is not waiting for the lock: the guard is
           held for a handful of instructions and never across a wait, so
           this still returns without waiting on the caller's behalf. */
        mutex_lock(mutex->guard);
        if (mutex->held) {
            mutex_unlock(mutex->guard);
            return SDL_MUTEX_TIMEDOUT;
        }
        mutex->held = 1;
        mutex_unlock(mutex->guard);
    }

    mutex->owner = self;
    mutex->recursive = 0;
    return 0;
}

int SDL_UnlockMutex(SDL_mutex *mutex)
{
    if (!mutex) {
        return SDL_SetError("Passed a NULL mutex");
    }
    if (mutex->owner != SDL_ThreadID()) {
        return SDL_SetError("mutex not owned by this thread");
    }
    if (mutex->recursive) {
        --mutex->recursive;
    } else {
        mutex->owner = 0;
        if (!MutexBlocking()) {
            mutex_unlock(mutex->guard);
        } else {
            mutex_lock(mutex->guard);
            mutex->held = 0;
            condition_signal(mutex->avail);
            mutex_unlock(mutex->guard);
        }
    }
    return 0;
}
