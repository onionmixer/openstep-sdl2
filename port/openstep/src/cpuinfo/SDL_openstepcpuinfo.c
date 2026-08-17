/*
 * OPENSTEP/i386 CPU-information backend.
 *
 * NeXT cc marks SDL's generic x86 CPUID translation unit as i586 even with
 * -m486. That prevents OPENSTEP's i386 loader from using a static SDL
 * archive. Keep the whole public API, using baseline-i386 answers.
 */
#include "../SDL_internal.h"

#include "SDL_cpuinfo.h"

int SDLCALL SDL_GetCPUCount(void)
{
    return 1;
}

int SDLCALL SDL_GetCPUCacheLineSize(void)
{
    return SDL_CACHELINE_SIZE;
}

#define OPENSTEP_NO_CPU_FEATURE(function_name) \
    SDL_bool SDLCALL function_name(void) \
    { \
        return SDL_FALSE; \
    }

OPENSTEP_NO_CPU_FEATURE(SDL_HasRDTSC)
OPENSTEP_NO_CPU_FEATURE(SDL_HasAltiVec)
OPENSTEP_NO_CPU_FEATURE(SDL_HasMMX)
OPENSTEP_NO_CPU_FEATURE(SDL_Has3DNow)
OPENSTEP_NO_CPU_FEATURE(SDL_HasSSE)
OPENSTEP_NO_CPU_FEATURE(SDL_HasSSE2)
OPENSTEP_NO_CPU_FEATURE(SDL_HasSSE3)
OPENSTEP_NO_CPU_FEATURE(SDL_HasSSE41)
OPENSTEP_NO_CPU_FEATURE(SDL_HasSSE42)
OPENSTEP_NO_CPU_FEATURE(SDL_HasAVX)
OPENSTEP_NO_CPU_FEATURE(SDL_HasAVX2)
OPENSTEP_NO_CPU_FEATURE(SDL_HasAVX512F)
OPENSTEP_NO_CPU_FEATURE(SDL_HasARMSIMD)
OPENSTEP_NO_CPU_FEATURE(SDL_HasNEON)
OPENSTEP_NO_CPU_FEATURE(SDL_HasLSX)
OPENSTEP_NO_CPU_FEATURE(SDL_HasLASX)

int SDLCALL SDL_GetSystemRAM(void)
{
    /* OPENSTEP has no portable physical-memory query in this port. */
    return 0;
}

size_t SDLCALL SDL_SIMDGetAlignment(void)
{
    /* The bundled i386 allocator guarantees normal eight-byte alignment. */
    return 8;
}

void *SDLCALL SDL_SIMDAlloc(const size_t length)
{
    return SDL_malloc(length);
}

void *SDLCALL SDL_SIMDRealloc(void *memory, const size_t length)
{
    return SDL_realloc(memory, length);
}

void SDLCALL SDL_SIMDFree(void *memory)
{
    SDL_free(memory);
}
