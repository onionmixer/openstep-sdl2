/* Verify the SDL default-button flags map to native Return and Escape keys. */
#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(int argc, char **argv)
{
    SDL_MessageBoxButtonData buttons[2];
    SDL_MessageBoxData data;
    int expected = 71;
    int selected = -99;

    if (argc > 1 && argv[1][0] == 'e') expected = 72;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-messagebox-key-defaults.log", "w", stdout)) {
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
    data.title = "SDL2 OPENSTEP key-default probe";
    data.message = expected == 71 ? "Press Return." : "Press Escape.";
    data.numbuttons = 2;
    data.buttons = buttons;
    printf("openstep-sdl-messagebox-key-defaults: waiting expected=%d\n", expected);
    fflush(stdout);
    if (SDL_ShowMessageBox(&data, &selected) != 0) {
        SDL_Quit();
        return 2;
    }
    SDL_Quit();
    if (selected != expected) return 3;
    printf("openstep-sdl-messagebox-key-defaults: PASS selected=%d\n", selected);
    return 0;
}
