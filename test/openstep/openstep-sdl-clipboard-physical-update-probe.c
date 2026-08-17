/* Physical external AppKit clipboard-change event probe.  Start it, then copy
   the expected token in Edit.app; it must receive SDL_CLIPBOARDUPDATE. */
#include <stdio.h>
#include <string.h>

#include "SDL.h"

static int Fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-clipboard-physical-update-probe: %s: %s\n",
            what, SDL_GetError());
    fflush(stdout);
    return 1;
}

int main(int argc, char **argv)
{
    static const char expected[] = "SDL2-Clipboard-Update-Physical-20260817";
    SDL_Window *window = NULL;
    SDL_Event event;
    Uint32 deadline;
    int result = 0;
    int saw_update = 0;

    (void)argc;
    (void)argv;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-clipboard-physical-update.log", "w", stdout)) {
        return 2;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return Fail("video init failed");
    window = SDL_CreateWindow("SDL2 clipboard update -- copy token in Edit.app (60 seconds)",
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              470, 90, 0);
    if (window == NULL) {
        result = Fail("window creation failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-clipboard-physical-update-probe: READY\n");
    fflush(stdout);
    deadline = SDL_GetTicks() + 60000;
    while (!saw_update && (Sint32)(deadline - SDL_GetTicks()) > 0) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_CLIPBOARDUPDATE) {
                char *text = SDL_GetClipboardText();
                saw_update = 1;
                fprintf(stdout, "openstep-sdl-clipboard-physical-update-probe: update text=%s\n",
                        text ? text : "(null)");
                if (text == NULL || strcmp(text, expected) != 0) {
                    result = Fail("clipboard update payload mismatch");
                }
                SDL_free(text);
                break;
            }
        }
        SDL_Delay(10);
    }
    if (!saw_update && result == 0) result = Fail("timed out waiting for SDL_CLIPBOARDUPDATE");

done:
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result == 0) {
        fprintf(stdout, "openstep-sdl-clipboard-physical-update-probe: PASS external update\n");
    }
    fflush(stdout);
    return result;
}
