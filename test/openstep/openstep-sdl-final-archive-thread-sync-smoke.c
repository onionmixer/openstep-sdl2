/* Public SDL thread/mutex/condition/semaphore test through final libSDL2.a. */
#include <stdio.h>

#include <mach/cthreads.h>

#include "SDL.h"

static SDL_mutex *sync_mutex;
static SDL_cond *sync_cond;
static SDL_sem *completion_sem;
static int worker_ready;
static int worker_release;

static int SDLCALL worker(void *unused)
{
    const char *name;

    (void)unused;
    name = cthread_name(cthread_self());
    if (name == NULL || SDL_strcmp(name, "final-thread-sync") != 0) return 1;
    if (SDL_LockMutex(sync_mutex) != 0) return 2;
    worker_ready = 1;
    while (!worker_release) {
        if (SDL_CondWait(sync_cond, sync_mutex) != 0) {
            SDL_UnlockMutex(sync_mutex);
            return 3;
        }
    }
    if (SDL_UnlockMutex(sync_mutex) != 0) return 4;
    if (SDL_SemPost(completion_sem) != 0) return 5;
    return 37;
}

int main(void)
{
    SDL_Thread *thread;
    int status = 0;
    int tries;

    if (SDL_Init(0) != 0) return 1;
    sync_mutex = SDL_CreateMutex();
    sync_cond = SDL_CreateCond();
    completion_sem = SDL_CreateSemaphore(0);
    if (!sync_mutex || !sync_cond || !completion_sem) {
        SDL_DestroySemaphore(completion_sem);
        SDL_DestroyCond(sync_cond);
        SDL_DestroyMutex(sync_mutex);
        SDL_Quit();
        return 2;
    }
    thread = SDL_CreateThread(worker, "final-thread-sync", NULL);
    if (!thread) {
        SDL_DestroySemaphore(completion_sem);
        SDL_DestroyCond(sync_cond);
        SDL_DestroyMutex(sync_mutex);
        SDL_Quit();
        return 3;
    }
    for (tries = 0; tries < 200; ++tries) {
        if (SDL_LockMutex(sync_mutex) != 0) break;
        if (worker_ready) {
            SDL_UnlockMutex(sync_mutex);
            break;
        }
        SDL_UnlockMutex(sync_mutex);
        SDL_Delay(5);
    }
    if (tries == 200) {
        if (SDL_LockMutex(sync_mutex) == 0) {
            worker_release = 1;
            SDL_CondSignal(sync_cond);
            SDL_UnlockMutex(sync_mutex);
        }
        SDL_WaitThread(thread, &status);
        SDL_DestroySemaphore(completion_sem);
        SDL_DestroyCond(sync_cond);
        SDL_DestroyMutex(sync_mutex);
        SDL_Quit();
        return 4;
    }
    if (SDL_LockMutex(sync_mutex) != 0) return 5;
    worker_release = 1;
    if (SDL_CondSignal(sync_cond) != 0 || SDL_UnlockMutex(sync_mutex) != 0 ||
        SDL_SemWaitTimeout(completion_sem, 1000) != 0) {
        SDL_WaitThread(thread, &status);
        SDL_DestroySemaphore(completion_sem);
        SDL_DestroyCond(sync_cond);
        SDL_DestroyMutex(sync_mutex);
        SDL_Quit();
        return 6;
    }
    SDL_WaitThread(thread, &status);
    SDL_DestroySemaphore(completion_sem);
    SDL_DestroyCond(sync_cond);
    SDL_DestroyMutex(sync_mutex);
    SDL_Quit();
    if (status != 37) return 7;

    printf("openstep-sdl-final-archive-thread-sync-smoke: PASS thread-name+mutex+cond+sem\n");
    return 0;
}
