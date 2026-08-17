/* Physical SDL2 -> Edit.app clipboard writer.  While this process remains
   alive, paste the fixed token into Edit.app to validate cross-app ownership. */
#include <stdio.h>
#include <string.h>

#include "SDL.h"

static int fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-clipboard-physical-write-probe: %s: %s\n",
            what, SDL_GetError());
    fflush(stdout);
    return 1;
}

int main(int argc, char **argv)
{
    static const char token[] = "SDL2-Clipboard-Write-Physical-20260817";
    SDL_Window *window = NULL;
    char *roundtrip;
    Uint32 deadline;
    int result = 0;

    (void)argc;
    (void)argv;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-clipboard-physical-write.log", "w", stdout)) {
        return 2;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    window = SDL_CreateWindow("SDL2 clipboard writer -- paste into Edit.app (60 seconds)",
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              430, 90, 0);
    if (window == NULL) {
        result = fail("writer window creation failed");
        goto done;
    }
    if (SDL_SetClipboardText(token) != 0) {
        result = fail("SDL_SetClipboardText failed");
        goto done;
    }
    roundtrip = SDL_GetClipboardText();
    if (roundtrip == NULL || strcmp(roundtrip, token) != 0) {
        if (roundtrip != NULL) SDL_free(roundtrip);
        result = fail("SDL clipboard roundtrip mismatch");
        goto done;
    }
    SDL_free(roundtrip);
    fprintf(stdout, "openstep-sdl-clipboard-physical-write-probe: READY token=%s\n", token);
    fflush(stdout);
    /* Give the operator time to paste into a separate AppKit application
       without starving the OPENSTEP AppKit run loop.  A single long
       SDL_Delay leaves its native window unresponsive (spinning cursor). */
    deadline = SDL_GetTicks() + 60000;
    while ((Sint32)(deadline - SDL_GetTicks()) > 0) {
        SDL_PumpEvents();
        SDL_Delay(10);
    }

done:
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result == 0) {
        fprintf(stdout, "openstep-sdl-clipboard-physical-write-probe: PASS write+roundtrip\n");
    }
    fflush(stdout);
    return result;
}
