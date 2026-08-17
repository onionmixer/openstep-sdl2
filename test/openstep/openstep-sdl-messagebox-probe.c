/* Interactive final gate: select the default Continue button in the native
   OPENSTEP alert and verify SDL receives its caller-supplied ID. */
#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(void)
{
    SDL_MessageBoxButtonData buttons[2];
    SDL_MessageBoxData data;
    int selected = -1;

    if (!freopen("/tmp/SDL20/log/openstep-sdl-messagebox-probe.log", "w", stdout)) {
        return 4;
    }
    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    SDL_zero(buttons);
    buttons[0].flags = SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT;
    buttons[0].buttonid = 71;
    buttons[0].text = "Continue";
    buttons[1].flags = SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT;
    buttons[1].buttonid = 72;
    buttons[1].text = "Cancel";
    SDL_zero(data);
    data.flags = SDL_MESSAGEBOX_INFORMATION;
    data.title = "SDL2 OPENSTEP message box";
    data.message = "Select Continue to verify the native AppKit alert.";
    data.numbuttons = 2;
    data.buttons = buttons;
    fprintf(stdout, "openstep-sdl-messagebox-probe: waiting for Continue\n");
    fflush(stdout);
    if (SDL_ShowMessageBox(&data, &selected) != 0) {
        SDL_Quit();
        return 2;
    }
    SDL_Quit();
    if (selected != 71) {
        fprintf(stderr, "openstep-sdl-messagebox-probe: selected %d, expected 71\n", selected);
        return 3;
    }
    printf("openstep-sdl-messagebox-probe: PASS selected=%d\n", selected);
    return 0;
}
