/*
 * Verify the OPENSTEP AppKit mouse bridge without depending on a physical
 * pointer route.  NSEvent's documented mouse-event factory supplies left and
 * right press/release events to the real SDL view.  The window is shown only
 * while the test runs and always closes itself.
 */
#import <AppKit/AppKit.h>

#include <stdio.h>

#include "SDL.h"

static int ConsumeMouseButtonEvent(Uint32 type, Uint8 button)
{
    SDL_Event event;
    int found = 0;

    while (SDL_PollEvent(&event)) {
        if (event.type == type && event.button.button == button) {
            found = 1;
        }
    }
    return found;
}

static NSEvent *MakeMouseEvent(NSWindow *window, NSEventType type,
                               NSPoint location, int event_number)
{
    return [NSEvent mouseEventWithType:type
                              location:location
                         modifierFlags:0
                             timestamp:0.0
                          windowNumber:[window windowNumber]
                               context:nil
                           eventNumber:event_number
                            clickCount:1
                              pressure:(type == NSLeftMouseDown ||
                                        type == NSRightMouseDown) ? 1.0 : 0.0];
}

static int SendAndCheck(SDL_Window *window, NSWindow *native, NSEventType native_type,
                        Uint32 sdl_type, Uint8 button, Uint32 expected_mask,
                        int event_number)
{
    NSEvent *event;
    Uint32 buttons;

    event = MakeMouseEvent(native, native_type, NSMakePoint(16.0, 16.0),
                           event_number);
    if (event == nil) return 1;
    [NSApp sendEvent:event];
    SDL_PumpEvents();
    buttons = SDL_GetMouseState(NULL, NULL);
    if (!ConsumeMouseButtonEvent(sdl_type, button)) return 2;
    if ((buttons & SDL_BUTTON(button)) != expected_mask) return 3;
    if (SDL_GetMouseFocus() != window) return 4;
    return 0;
}

int main(void)
{
    SDL_Window *window;
    NSWindow *native;
    int result = 0;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 OPENSTEP mouse event smoke",
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
        result = SendAndCheck(window, native, NSLeftMouseDown, SDL_MOUSEBUTTONDOWN,
                              SDL_BUTTON_LEFT, SDL_BUTTON(SDL_BUTTON_LEFT), 1);
        if (result == 0) {
            result = SendAndCheck(window, native, NSLeftMouseUp, SDL_MOUSEBUTTONUP,
                                  SDL_BUTTON_LEFT, 0, 2);
        }
        if (result == 0) {
            result = SendAndCheck(window, native, NSRightMouseDown, SDL_MOUSEBUTTONDOWN,
                                  SDL_BUTTON_RIGHT, SDL_BUTTON(SDL_BUTTON_RIGHT), 3);
        }
        if (result == 0) {
            result = SendAndCheck(window, native, NSRightMouseUp, SDL_MOUSEBUTTONUP,
                                  SDL_BUTTON_RIGHT, 0, 4);
        }
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-mouse-events-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-final-archive-mouse-events-smoke: PASS synthetic left+right press/release\n");
    return 0;
}
