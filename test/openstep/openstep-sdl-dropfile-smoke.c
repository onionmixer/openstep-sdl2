/* Interactive standard SDL2 file-drop smoke for the OPENSTEP AppKit backend.
   Run from Workspace, then drop one or more files on the window within 5 min. */
#include <stdio.h>

#include "SDL.h"

static int fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-dropfile-smoke: %s: %s\n", what, SDL_GetError());
    fflush(stdout);
    return 1;
}

int main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Event event;
    Uint32 deadline;
    int saw_begin = 0;
    int saw_file = 0;
    int saw_complete = 0;

    (void)argc;
    (void)argv;
    /* GCD starts GUI clients asynchronously, so retain the physical result
       on the target instead of relying on the launch client's stdout. */
    if (!freopen("/tmp/SDL20/log/openstep-sdl-dropfile-record.log", "w", stdout)) {
        return 2;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    window = SDL_CreateWindow("Drop files here (5 minutes)", 54, 54, 300, 120, 0);
    if (!window) {
        SDL_Quit();
        return fail("window creation failed");
    }

    /* Exercise SDL core's backend registration transition. Disable both
       accepted event kinds, then enable only SDL_DROPFILE before dragging. */
    SDL_EventState(SDL_DROPTEXT, SDL_DISABLE);
    SDL_EventState(SDL_DROPFILE, SDL_DISABLE);
    SDL_EventState(SDL_DROPFILE, SDL_ENABLE);
    deadline = SDL_GetTicks() + 300000;
    while (!saw_complete && (Sint32)(deadline - SDL_GetTicks()) > 0) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_DROPBEGIN) {
                if (saw_begin || saw_file) {
                    SDL_DestroyWindow(window);
                    SDL_Quit();
                    return fail("invalid duplicate SDL_DROPBEGIN ordering");
                }
                saw_begin = 1;
            } else if (event.type == SDL_DROPFILE) {
                if (!saw_begin || !event.drop.file || !event.drop.file[0]) {
                    if (event.drop.file) SDL_free(event.drop.file);
                    SDL_DestroyWindow(window);
                    SDL_Quit();
                    return fail("invalid SDL_DROPFILE payload or ordering");
                }
                printf("openstep-sdl-dropfile-smoke: file=%s\n", event.drop.file);
                SDL_free(event.drop.file);
                saw_file = 1;
            } else if (event.type == SDL_DROPCOMPLETE) {
                if (!saw_begin || !saw_file) {
                    SDL_DestroyWindow(window);
                    SDL_Quit();
                    return fail("invalid SDL_DROPCOMPLETE ordering");
                }
                saw_complete = 1;
            } else if (event.type == SDL_QUIT) {
                SDL_DestroyWindow(window);
                SDL_Quit();
                return fail("window was closed before drop completed");
            }
        }
        SDL_Delay(10);
    }
    SDL_EventState(SDL_DROPTEXT, SDL_ENABLE);
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (!saw_complete) return fail("timed out waiting for a file drop");
    printf("openstep-sdl-dropfile-smoke: PASS begin/file/complete sequence\n");
    fflush(stdout);
    return 0;
}
