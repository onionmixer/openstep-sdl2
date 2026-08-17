#include <libc.h>
#include <mach/cthreads.h>
#include <stdlib.h>
#include <sys/time.h>

#include "SDL_mutex.h"
#include "SDL_thread.h"

#define BROADCAST_WORKERS 3

static SDL_cond *test_cond;
static SDL_mutex *test_mutex;
static int release_workers;
static int waiting_workers;
static int completed_workers;

void *SDL_calloc(size_t nmemb, size_t size)
{
    return calloc(nmemb, size);
}

void SDL_free(void *memory)
{
    free(memory);
}

int SDL_Error(SDL_errorcode code)
{
    (void)code;
    return -1;
}

int SDL_SetError(const char *fmt, ...)
{
    (void)fmt;
    return -1;
}

SDL_threadID SDL_ThreadID(void)
{
    return (SDL_threadID)(unsigned long)cthread_self();
}

static void delay_one_millisecond(void)
{
    struct timeval delay;

    delay.tv_sec = 0;
    delay.tv_usec = 1000;
    select(0, 0, 0, 0, &delay);
}

static int wait_for_waiters(int expected)
{
    int tries;
    int result;

    result = -1;
    for (tries = 0; tries < 1000; ++tries) {
        if (SDL_LockMutex(test_mutex) != 0) {
            return -1;
        }
        if (waiting_workers == expected) {
            result = 0;
        }
        if (SDL_UnlockMutex(test_mutex) != 0) {
            return -1;
        }
        if (result == 0) {
            return 0;
        }
        delay_one_millisecond();
    }
    return -1;
}

static any_t condition_worker(any_t unused)
{
    (void)unused;
    if (SDL_LockMutex(test_mutex) != 0) {
        return (any_t)1;
    }
    ++waiting_workers;
    while (!release_workers) {
        if (SDL_CondWait(test_cond, test_mutex) != 0) {
            SDL_UnlockMutex(test_mutex);
            return (any_t)2;
        }
    }
    --waiting_workers;
    ++completed_workers;
    if (SDL_UnlockMutex(test_mutex) != 0) {
        return (any_t)3;
    }
    return (any_t)0;
}

int main(void)
{
    cthread_t workers[BROADCAST_WORKERS];
    int index;

    cthread_init();
    test_mutex = SDL_CreateMutex();
    test_cond = SDL_CreateCond();
    if (!test_mutex || !test_cond) {
        return 1;
    }

    if (SDL_LockMutex(test_mutex) != 0 ||
        SDL_CondWaitTimeout(test_cond, test_mutex, 10) != SDL_MUTEX_TIMEDOUT ||
        SDL_UnlockMutex(test_mutex) != 0) {
        return 2;
    }

    workers[0] = cthread_fork((cthread_fn_t)condition_worker, (any_t)0);
    if (workers[0] == NO_CTHREAD || wait_for_waiters(1) != 0) {
        return 3;
    }
    if (SDL_LockMutex(test_mutex) != 0) {
        return 4;
    }
    release_workers = 1;
    if (SDL_CondSignal(test_cond) != 0 || SDL_UnlockMutex(test_mutex) != 0 ||
        cthread_join(workers[0]) != 0 || completed_workers != 1) {
        return 5;
    }

    release_workers = 0;
    for (index = 0; index < BROADCAST_WORKERS; ++index) {
        workers[index] = cthread_fork((cthread_fn_t)condition_worker, (any_t)0);
        if (workers[index] == NO_CTHREAD) {
            return 6;
        }
    }
    if (wait_for_waiters(BROADCAST_WORKERS) != 0 ||
        SDL_LockMutex(test_mutex) != 0) {
        return 7;
    }
    release_workers = 1;
    if (SDL_CondBroadcast(test_cond) != 0 || SDL_UnlockMutex(test_mutex) != 0) {
        return 8;
    }
    for (index = 0; index < BROADCAST_WORKERS; ++index) {
        if (cthread_join(workers[index]) != 0) {
            return 9;
        }
    }
    if (waiting_workers != 0 || completed_workers != BROADCAST_WORKERS + 1) {
        return 10;
    }
    SDL_DestroyCond(test_cond);
    SDL_DestroyMutex(test_mutex);
    return 0;
}
