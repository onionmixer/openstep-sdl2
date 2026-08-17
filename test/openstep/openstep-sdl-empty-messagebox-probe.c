/* SDL permits a custom message box with no button-data entries.  OPENSTEP
   supplies an implicit OK and must return the conventional -1 selection. */
#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(void)
{
    SDL_MessageBoxData data;
    int selected = -99;

    if (!freopen("/tmp/SDL20/log/openstep-sdl-empty-messagebox-probe.log", "w", stdout)) {
        return 4;
    }
    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    SDL_zero(data);
    data.flags = SDL_MESSAGEBOX_INFORMATION;
    data.title = "SDL2 OPENSTEP empty custom message box";
    data.message = "Select OK to verify zero custom buttons.";
    data.numbuttons = 0;
    data.buttons = NULL;
    printf("openstep-sdl-empty-messagebox-probe: waiting for OK\n");
    fflush(stdout);
    if (SDL_ShowMessageBox(&data, &selected) != 0) {
        SDL_Quit();
        return 2;
    }
    SDL_Quit();
    if (selected != -1) return 3;
    printf("openstep-sdl-empty-messagebox-probe: PASS selected=%d\n", selected);
    return 0;
}
