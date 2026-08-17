#include "SDL_atomic.h"
#include "SDL_timer.h"

/* SDL_spinlock.c references SDL_Delay only on a contended spin. This test is
   single-threaded, but supplies the symbol so the complete fallback links. */
void SDL_Delay(Uint32 ms)
{
    (void)ms;
}

int main(void)
{
    SDL_atomic_t value;
    int previous;

    SDL_AtomicSet(&value, 3);
    previous = SDL_AtomicAdd(&value, 4);
    if (previous != 3 || SDL_AtomicGet(&value) != 7) {
        return 1;
    }
    if (!SDL_AtomicCAS(&value, 7, 9) || SDL_AtomicGet(&value) != 9) {
        return 2;
    }
    return 0;
}

