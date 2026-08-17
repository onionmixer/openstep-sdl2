/* Interactive custom-button gate.  The OPENSTEP native panel deliberately
   avoids NSRunAlertPanel's three-button ceiling, so SDL custom buttons must
   retain both their count and caller-provided IDs. */
#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(void)
{
    SDL_MessageBoxButtonData buttons[4];
    SDL_MessageBoxData data;
    int selected = -99;
    int i;

    if (!freopen("/tmp/SDL20/log/openstep-sdl-messagebox-custom-buttons.log", "w", stdout)) {
        return 4;
    }
    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    for (i = 0; i < 4; ++i) {
        buttons[i].flags = 0;
        buttons[i].buttonid = 101 + i;
    }
    buttons[0].text = "One";
    buttons[1].text = "Two";
    buttons[2].text = "Three";
    buttons[3].text = "Four";
    SDL_zero(data);
    data.title = "OPENSTEP SDL2 custom button probe";
    data.message = "Select Four to verify all four SDL custom buttons.";
    data.numbuttons = 4;
    data.buttons = buttons;
    if (SDL_ShowMessageBox(&data, &selected) != 0) {
        SDL_Quit();
        return 2;
    }
    if (selected != 104) {
        SDL_Quit();
        return 3;
    }
    SDL_Quit();
    printf("openstep-sdl-messagebox-limits-smoke: PASS selected=%d\n", selected);
    return 0;
}
