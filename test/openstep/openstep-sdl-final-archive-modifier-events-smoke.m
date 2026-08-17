/*
 * Verify the OPENSTEP AppKit flagsChanged: bridge without physical input.
 * NSEvent's documented key-event factory lets this create a real responder
 * event for the SDL view; the window is shown briefly and always closes.
 */
#import <AppKit/AppKit.h>

#include <stdio.h>

#include "SDL.h"

static int ConsumeModifierEvent(Uint32 type, SDL_Scancode scancode)
{
    SDL_Event event;
    int found = 0;

    while (SDL_PollEvent(&event)) {
        if (event.type == type && event.key.keysym.scancode == scancode) {
            found = 1;
        }
    }
    return found;
}

static NSEvent *MakeFlagsEvent(NSWindow *window, unsigned int flags)
{
    return [NSEvent keyEventWithType:NSFlagsChanged
                            location:NSMakePoint(0.0, 0.0)
                       modifierFlags:flags
                           timestamp:0.0
                        windowNumber:[window windowNumber]
                             context:nil
                          characters:@""
       charactersIgnoringModifiers:@""
                           isARepeat:NO
                             keyCode:0];
}

static int CheckModifierTransition(NSWindow *native, unsigned int flags,
                                   SDL_Scancode scancode, SDL_Keymod mod)
{
    NSEvent *press;
    NSEvent *release;
    const Uint8 *keyboard;

    press = MakeFlagsEvent(native, flags);
    release = MakeFlagsEvent(native, 0);
    if (press == nil || release == nil) return 1;
    [NSApp sendEvent:press];
    SDL_PumpEvents();
    keyboard = SDL_GetKeyboardState(NULL);
    if (!ConsumeModifierEvent(SDL_KEYDOWN, scancode) ||
        keyboard[scancode] == 0 || (SDL_GetModState() & mod) == 0) {
        return 2;
    }
    [NSApp sendEvent:release];
    SDL_PumpEvents();
    keyboard = SDL_GetKeyboardState(NULL);
    if (!ConsumeModifierEvent(SDL_KEYUP, scancode) ||
        keyboard[scancode] != 0 || (SDL_GetModState() & mod) != 0) {
        return 3;
    }
    return 0;
}

static int CheckEventClassificationIsNotSDLModifier(NSWindow *native,
                                                    unsigned int flags)
{
    NSEvent *classification_event;
    NSEvent *release;

    classification_event = MakeFlagsEvent(native, flags);
    release = MakeFlagsEvent(native, 0);
    if (classification_event == nil || release == nil) return 1;
    [NSApp sendEvent:classification_event];
    SDL_PumpEvents();
    if ((SDL_GetModState() & (KMOD_MODE | KMOD_NUM)) != 0) return 2;
    [NSApp sendEvent:release];
    SDL_PumpEvents();
    return (SDL_GetModState() & (KMOD_MODE | KMOD_NUM)) != 0 ? 3 : 0;
}

int main(void)
{
    SDL_Window *window;
    NSWindow *native;
    int result = 0;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 OPENSTEP modifier event smoke",
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
        result = CheckModifierTransition(native, NSShiftKeyMask,
                                         SDL_SCANCODE_LSHIFT, KMOD_LSHIFT);
        if (result == 0) result = CheckModifierTransition(native, NSControlKeyMask,
                                                           SDL_SCANCODE_LCTRL, KMOD_LCTRL);
        if (result == 0) result = CheckModifierTransition(native, NSAlternateKeyMask,
                                                           SDL_SCANCODE_LALT, KMOD_LALT);
        if (result == 0) result = CheckModifierTransition(native, NSCommandKeyMask,
                                                           SDL_SCANCODE_LGUI, KMOD_LGUI);
        if (result == 0) result = CheckEventClassificationIsNotSDLModifier(native,
                                                                             NSFunctionKeyMask);
        if (result == 0) result = CheckEventClassificationIsNotSDLModifier(native,
                                                                             NSNumericPadKeyMask);
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-modifier-events-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-final-archive-modifier-events-smoke: PASS synthetic Shift/Control/Alt/Command plus function/keypad classifications\n");
    return 0;
}
