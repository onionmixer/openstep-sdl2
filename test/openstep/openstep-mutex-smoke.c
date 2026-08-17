#include <mach/cthreads.h>
#include <stdlib.h>

#include "SDL_mutex.h"
#include "SDL_thread.h"

#define WORKER_COUNT 2
#define INCREMENTS_PER_WORKER 10000

static SDL_mutex *shared_mutex;
static int shared_counter;

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

static any_t worker(any_t unused)
{
    int index;

    (void)unused;
    for (index = 0; index < INCREMENTS_PER_WORKER; ++index) {
        if (SDL_LockMutex(shared_mutex) != 0) {
            return (any_t)1;
        }
        ++shared_counter;
        SDL_UnlockMutex(shared_mutex);
    }
    return (any_t)0;
}

int main(void)
{
    cthread_t workers[WORKER_COUNT];
    int index;

    cthread_init();
    shared_mutex = SDL_CreateMutex();
    if (!shared_mutex) {
        return 1;
    }
    if (SDL_LockMutex(shared_mutex) != 0 ||
        SDL_TryLockMutex(shared_mutex) != 0 ||
        SDL_UnlockMutex(shared_mutex) != 0 ||
        SDL_UnlockMutex(shared_mutex) != 0) {
        return 2;
    }
    for (index = 0; index < WORKER_COUNT; ++index) {
        workers[index] = cthread_fork((cthread_fn_t)worker, (any_t)0);
        if (workers[index] == NO_CTHREAD) {
            return 3;
        }
    }
    for (index = 0; index < WORKER_COUNT; ++index) {
        if (cthread_join(workers[index]) != 0) {
            return 4;
        }
    }
    if (shared_counter != WORKER_COUNT * INCREMENTS_PER_WORKER) {
        return 5;
    }
    SDL_DestroyMutex(shared_mutex);
    return 0;
}
