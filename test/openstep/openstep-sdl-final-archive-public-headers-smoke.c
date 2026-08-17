/*
 * Consume the complete ordinary SDL2 runtime public-header set through the
 * final archive.  This is deliberately headless: it checks the opt-in SYSWM
 * and Vulkan unsupported paths without creating an AppKit window.
 */
#include <stdio.h>

#include "SDL.h"
#include "SDL_syswm.h"
#include "SDL_vulkan.h"

SDL_COMPILE_TIME_ASSERT(openstep_public_uint64, sizeof(Uint64) == 8);
/* The OPENSTEP ABI target is i486/32-bit.  The earlier target-only header
   smoke also checks pointer equality; this fixed-width form lets the same
   public-header source receive a useful 64-bit host syntax check. */
SDL_COMPILE_TIME_ASSERT(openstep_public_uintptr, sizeof(uintptr_t) == 4);

int main(void)
{
    SDL_version version;
    SDL_SysWMinfo info;
    SDL_Rect rect;
    SDL_FRect frect;
    Uint32 value;

    SDL_VERSION(&version);
    SDL_zero(info);
    SDL_VERSION(&info.version);
    rect.x = 1;
    rect.y = 2;
    rect.w = 0;
    rect.h = 3;
    frect.x = 1.0f;
    frect.y = 2.0f;
    frect.w = 4.0f;
    frect.h = 5.0f;
    value = 0x12345678U;

    if (version.major != SDL_MAJOR_VERSION || !SDL_RectEmpty(&rect) ||
        !SDL_FRectEqualsEpsilon(&frect, &frect, 0.0f) ||
        SDL_Swap32(SDL_Swap32(value)) != value) {
        return 1;
    }
    if (SDL_Init(0) != 0) return 2;

    /* OPENSTEP has no SDL_SYSWM_OPENSTEP structure, so this standard API
       must fail cleanly rather than return an invented native handle. */
    if (SDL_GetWindowWMInfo(NULL, &info) != SDL_FALSE) {
        SDL_Quit();
        return 3;
    }

    /* Vulkan is not available on the Mesa 3.4.2/OpenGL 1.2 target.  Link and
       execute the public fallback path; a successful load is not required. */
    (void)SDL_Vulkan_LoadLibrary(NULL);
    if (SDL_Vulkan_GetVkGetInstanceProcAddr() != NULL) {
        SDL_Vulkan_UnloadLibrary();
        SDL_Quit();
        return 4;
    }
    SDL_Vulkan_UnloadLibrary();
    SDL_Quit();

    printf("openstep-sdl-final-archive-public-headers-smoke: PASS runtime headers+syswm+vulkan fallback\n");
    return 0;
}
