/* Verify that an AppKit close-button request remains an SDL close event.
   The test leaves the native window alive until SDL itself destroys it. */
#import <AppKit/AppKit.h>

#include <stdio.h>

#include "SDL.h"

static int ConsumeCloseEvent(void)
{
    SDL_Event event;
    int found = 0;

    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_WINDOWEVENT &&
            event.window.event == SDL_WINDOWEVENT_CLOSE) {
            found = 1;
        }
    }
    return found;
}

int main(void)
{
    SDL_Window *window;
    NSWindow *native;
    int width;
    int height;
    int result = 0;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 OPENSTEP close request smoke",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              96, 64, SDL_WINDOW_SHOWN);
    if (window == NULL) {
        SDL_Quit();
        return 2;
    }
    SDL_PumpEvents();
    native = [NSApp keyWindow];
    if (native == nil) native = [NSApp mainWindow];
    if (native == nil) {
        result = 3;
    } else {
        [NSApp activateIgnoringOtherApps:YES];
        [native makeKeyAndOrderFront:nil];
        [native performClose:nil];
        SDL_PumpEvents();
        if (!ConsumeCloseEvent()) {
            result = 4;
        } else if (![native isVisible]) {
            result = 5;
        } else {
            SDL_SetWindowTitle(window, "SDL2 OPENSTEP close request retained");
            SDL_GetWindowSize(window, &width, &height);
            if (width != 96 || height != 64) result = 6;
        }
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-close-request-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-final-archive-close-request-smoke: PASS close event retains SDL window\n");
    return 0;
}
