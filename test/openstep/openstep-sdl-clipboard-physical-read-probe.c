/* Physical cross-application clipboard reader.  Copy the exact ASCII token
   from Edit.app before launching this final-archive SDL2 consumer. */
#include <stdio.h>
#include <string.h>

#include "SDL.h"

static int fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-clipboard-physical-read-probe: %s: %s\n",
            what, SDL_GetError());
    fflush(stdout);
    return 1;
}

int main(int argc, char **argv)
{
    static const char expected[] = "SDL2-Clipboard-Physical-20260817";
    char *text;
    int result = 0;

    (void)argc;
    (void)argv;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-clipboard-physical-read.log", "w", stdout)) {
        return 2;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    if (!SDL_HasClipboardText()) {
        result = fail("external clipboard has no text");
        goto done;
    }
    text = SDL_GetClipboardText();
    if (text == NULL) {
        result = fail("SDL_GetClipboardText failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-clipboard-physical-read-probe: text=%s\n", text);
    if (strcmp(text, expected) != 0) {
        fprintf(stdout, "openstep-sdl-clipboard-physical-read-probe: expected=%s\n", expected);
        result = 1;
    }
    SDL_free(text);

done:
    SDL_Quit();
    if (result == 0) {
        fprintf(stdout, "openstep-sdl-clipboard-physical-read-probe: PASS external Edit text\n");
    }
    fflush(stdout);
    return result;
}
