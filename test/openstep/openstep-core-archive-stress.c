#include "SDL.h"
#include "SDL_atomic.h"
#include "core/SDL_maincore.h"
#include "thread/SDL_thread_c.h"
#include "timer/SDL_timer_c.h"

#define CYCLES 10
#define WORKERS 4
#define INCREMENTS 200
#define CORE_RESTARTS 3

typedef struct Work
{
    int value;
} Work;

static SDL_TLSID stress_tls_id;
static SDL_atomic_t increment_count;
static SDL_atomic_t destructor_count;
static SDL_atomic_t timer_count;

static void SDLCALL stress_destructor(void *data)
{
    if (data) {
        SDL_AtomicIncRef(&destructor_count);
    }
}

static int SDLCALL stress_worker(void *userdata)
{
    Work *work;
    int index;

    work = (Work *)userdata;
    if (SDL_TLSSet(stress_tls_id, work, stress_destructor) != 0 ||
        SDL_TLSGet(stress_tls_id) != work) {
        return -1;
    }
    for (index = 0; index < INCREMENTS; ++index) {
        SDL_AtomicIncRef(&increment_count);
    }
    SDL_Delay(1);
    return work->value;
}

static Uint32 SDLCALL stress_timer(Uint32 interval, void *userdata)
{
    (void)interval;
    (void)userdata;
    SDL_AtomicIncRef(&timer_count);
    return 0;
}

int main(void)
{
    SDL_Thread *threads[WORKERS];
    Work work[WORKERS];
    int allocations_before;
    int restart;
    int cycle;
    int index;
    int status;
    int tries;

    allocations_before = SDL_GetNumAllocations();
    for (restart = 0; restart < CORE_RESTARTS; ++restart) {
        stress_tls_id = SDL_TLSCreate();
        if (!stress_tls_id || SDL_TimerInit() != 0) {
            return 1;
        }

        for (cycle = 0; cycle < CYCLES; ++cycle) {
            for (index = 0; index < WORKERS; ++index) {
                work[index].value = cycle * WORKERS + index + 1;
                threads[index] = SDL_CreateThread(stress_worker, "core-stress", &work[index]);
                if (!threads[index]) {
                    SDL_TimerQuit();
                    return 2;
                }
            }
            if (!SDL_AddTimer(5, stress_timer, NULL)) {
                SDL_TimerQuit();
                return 3;
            }
            for (index = 0; index < WORKERS; ++index) {
                status = 0;
                SDL_WaitThread(threads[index], &status);
                if (status != work[index].value) {
                    SDL_TimerQuit();
                    return 4;
                }
            }
            for (tries = 0; tries < 100 && SDL_AtomicGet(&timer_count) < (restart * CYCLES) + cycle + 1; ++tries) {
                SDL_Delay(2);
            }
            if (SDL_AtomicGet(&timer_count) != (restart * CYCLES) + cycle + 1) {
                SDL_TimerQuit();
                return 5;
            }
        }

        SDL_TimerQuit();
        if (SDL_AtomicGet(&increment_count) != (restart + 1) * CYCLES * WORKERS * INCREMENTS ||
            SDL_AtomicGet(&destructor_count) != (restart + 1) * CYCLES * WORKERS) {
            return 6;
        }
        SDL_OpenStepQuitCore();
        if (SDL_GetNumAllocations() != allocations_before) {
            return 7;
        }
    }
    return 0;
}
