/* Verify SDL_ShowSimpleMessageBox uses the OPENSTEP native panel and returns
   after its implicit default/escape OK button is selected. */
#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(void)
{
    if (!freopen("/tmp/SDL20/log/openstep-sdl-simple-messagebox-probe.log", "w", stdout)) {
        return 4;
    }
    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    printf("openstep-sdl-simple-messagebox-probe: waiting for OK\n");
    fflush(stdout);
    if (SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_INFORMATION,
                                 "SDL2 OPENSTEP simple message box",
                                 "Select OK to verify the standard simple API.",
                                 NULL) != 0) {
        SDL_Quit();
        return 2;
    }
    SDL_Quit();
    printf("openstep-sdl-simple-messagebox-probe: PASS\n");
    return 0;
}
