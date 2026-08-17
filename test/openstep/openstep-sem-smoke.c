#include <mach/cthreads.h>
#include <stdlib.h>

#include "SDL_mutex.h"

static SDL_sem *test_sem;

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

static any_t wait_worker(any_t unused)
{
    (void)unused;
    return (any_t)SDL_SemWait(test_sem);
}

int main(void)
{
    cthread_t worker;

    cthread_init();
    test_sem = SDL_CreateSemaphore(1);
    if (!test_sem) {
        return 1;
    }
    if (SDL_SemValue(test_sem) != 1 || SDL_SemTryWait(test_sem) != 0 ||
        SDL_SemValue(test_sem) != 0) {
        return 2;
    }
    if (SDL_SemTryWait(test_sem) != SDL_MUTEX_TIMEDOUT) {
        return 3;
    }
    if (SDL_SemWaitTimeout(test_sem, 10) != SDL_MUTEX_TIMEDOUT) {
        return 4;
    }
    worker = cthread_fork((cthread_fn_t)wait_worker, (any_t)0);
    if (worker == NO_CTHREAD) {
        return 5;
    }
    if (SDL_SemPost(test_sem) != 0 || cthread_join(worker) != 0 ||
        SDL_SemValue(test_sem) != 0) {
        return 6;
    }
    if (SDL_SemPost(test_sem) != 0 || SDL_SemValue(test_sem) != 1) {
        return 7;
    }
    SDL_DestroySemaphore(test_sem);
    return 0;
}
