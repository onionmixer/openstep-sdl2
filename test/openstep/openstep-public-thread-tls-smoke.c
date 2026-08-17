/*
 * Public SDL thread API smoke with real SDL malloc/string/hints/error/TLS
 * sources. SDL.c cannot yet be linked because its subsystem dispatchers have
 * no OPENSTEP video/audio/timer backends; this is its relevant thread bootstrap
 * only, deliberately kept in the test rather than the port source tree.
 */
#include "thread/SDL_thread_c.h"
#include "SDL_timer.h"

static SDL_TLSID test_tls_id;
static int child_value = 73;
static int main_value = 29;
static int destructor_called;
static int destructor_value_matched;
static SDL_threadID worker_thread_id;

/* This is the thread-relevant body of SDL_InitMainThread() in src/SDL.c. */
void SDL_InitMainThread(void)
{
    SDL_InitTLSData();
}

static void SDLCALL test_destructor(void *data)
{
    destructor_called = 1;
    if (data == &child_value) {
        destructor_value_matched = 1;
    }
}

static int SDLCALL public_thread_worker(void *unused)
{
    (void)unused;
    worker_thread_id = SDL_ThreadID();
    if (SDL_TLSSet(test_tls_id, &child_value, test_destructor) != 0) {
        return 1;
    }
    if (SDL_TLSGet(test_tls_id) != &child_value) {
        return 2;
    }
    return child_value;
}

int main(void)
{
    SDL_Thread *thread;
    int status;
    int allocations_before;

    allocations_before = SDL_GetNumAllocations();
    SDL_Delay(1);
    test_tls_id = SDL_TLSCreate();
    if (!test_tls_id) {
        return 1;
    }
    if (SDL_TLSSet(test_tls_id, &main_value, NULL) != 0 ||
        SDL_TLSGet(test_tls_id) != &main_value) {
        return 2;
    }

    thread = SDL_CreateThread(public_thread_worker, "public-tls", NULL);
    if (!thread || SDL_GetThreadName(thread) == NULL) {
        return 3;
    }
    SDL_WaitThread(thread, &status);
    if (status != child_value || worker_thread_id == 0 || !destructor_called ||
        !destructor_value_matched) {
        return 4;
    }
    if (SDL_TLSGet(test_tls_id) != &main_value) {
        return 5;
    }

    SDL_QuitTLSData();
    if (SDL_GetNumAllocations() != allocations_before) {
        return 6;
    }
    return 0;
}
