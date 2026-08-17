#include "SDL_cpuinfo.h"
#include "SDL_stdinc.h"
#include "thread/SDL_thread_c.h"

/* This is the thread-relevant initialization body in upstream SDL.c. The
   full dispatcher is deliberately not pulled into this CPU-only smoke. */
void SDL_InitMainThread(void)
{
    SDL_InitTLSData();
}

int main(void)
{
    size_t alignment;
    Uint8 *memory;
    Uint8 *resized;
    int cpu_count;

    cpu_count = SDL_GetCPUCount();
    if (cpu_count < 1) {
        return 1;
    }

    /* Exercise the complete conservative OPENSTEP CPU-info API surface. */
    (void)SDL_GetCPUCacheLineSize();
    (void)SDL_HasRDTSC();
    (void)SDL_HasMMX();
    (void)SDL_Has3DNow();
    (void)SDL_HasSSE();
    (void)SDL_HasSSE2();

    alignment = SDL_SIMDGetAlignment();
    if (alignment == 0 || (alignment & (alignment - 1)) != 0) {
        return 2;
    }
    memory = (Uint8 *)SDL_SIMDAlloc(17);
    if (!memory || (((size_t)memory) % alignment) != 0) {
        SDL_SIMDFree(memory);
        return 3;
    }
    memory[0] = 0x31;
    memory[16] = 0x7c;
    resized = (Uint8 *)SDL_SIMDRealloc(memory, 64);
    if (!resized || (((size_t)resized) % alignment) != 0) {
        SDL_SIMDFree(resized);
        return 4;
    }
    SDL_SIMDFree(resized);
    SDL_SIMDFree(NULL);
    return 0;
}
