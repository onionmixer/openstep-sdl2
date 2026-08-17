/* Verify SDL's video-bootstrap message-box callback before SDL_Init(). */
#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(void)
{
    if (!freopen("/tmp/SDL20/log/openstep-sdl-bootstrap-messagebox-probe.log", "w", stdout)) {
        return 4;
    }
    SDL_SetMainReady();
    SDL_InitMainThread();
    if (!SDL_SetHint(SDL_HINT_VIDEODRIVER, "openstep")) {
        return 1;
    }
    printf("openstep-sdl-bootstrap-messagebox-probe: waiting for OK\n");
    fflush(stdout);
    if (SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_INFORMATION,
                                 "SDL2 OPENSTEP bootstrap message box",
                                 "Select OK; SDL_Init has not been called.",
                                 NULL) != 0) {
        return 2;
    }
    printf("openstep-sdl-bootstrap-messagebox-probe: PASS\n");
    return 0;
}
