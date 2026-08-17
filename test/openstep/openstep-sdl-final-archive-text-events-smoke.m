/*
 * Verify AppKit key-event translation through the final SDL2 archive without
 * physical keyboard input.  The event contains an unmodified ASCII key for
 * scancode selection and a non-ASCII composed text value, proving that the
 * backend preserves the full NSString and encodes SDL_TEXTINPUT as UTF-8.
 */
#import <AppKit/AppKit.h>

#include <stdio.h>

#include "SDL.h"

static int IsAcuteE(const char *text)
{
    return ((unsigned char)text[0] == 0xc3 &&
            (unsigned char)text[1] == 0xa9 && text[2] == '\0');
}

static int ConsumeKeyAndText(Uint32 key_type, SDL_Scancode scancode,
                             int require_text)
{
    SDL_Event event;
    int key_found = 0;
    int text_found = 0;
    int unexpected_text = 0;

    while (SDL_PollEvent(&event)) {
        if (event.type == key_type && event.key.keysym.scancode == scancode) {
            key_found = 1;
        }
        if (event.type == SDL_TEXTINPUT) {
            if (require_text && IsAcuteE(event.text.text)) {
                text_found = 1;
            } else if (!require_text) {
                unexpected_text = 1;
            }
        }
    }
    return key_found && (!require_text || text_found) && !unexpected_text;
}

static NSEvent *MakeKeyEvent(NSWindow *window, NSEventType type,
                             NSString *characters, NSString *unmodified)
{
    return [NSEvent keyEventWithType:type
                            location:NSMakePoint(0.0, 0.0)
                       modifierFlags:0
                           timestamp:0.0
                        windowNumber:[window windowNumber]
                             context:nil
                          characters:characters
       charactersIgnoringModifiers:unmodified
                           isARepeat:NO
                             keyCode:0];
}

int main(void)
{
    SDL_Window *window;
    NSWindow *native;
    unichar acute_e = 0x00e9;
    unichar up_arrow = NSUpArrowFunctionKey;
    NSString *characters;
    NSString *unmodified;
    NSString *arrow;
    NSEvent *down;
    NSEvent *up;
    const Uint8 *keyboard;
    int result = 0;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 OPENSTEP text event smoke",
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
        characters = [NSString stringWithCharacters:&acute_e length:1];
        unmodified = @"e";
        arrow = [NSString stringWithCharacters:&up_arrow length:1];
        down = MakeKeyEvent(native, NSKeyDown, characters, unmodified);
        up = MakeKeyEvent(native, NSKeyUp, characters, unmodified);
        if (characters == nil || arrow == nil || down == nil || up == nil) {
            result = 4;
        } else {
            SDL_StartTextInput();
            [NSApp sendEvent:down];
            SDL_PumpEvents();
            keyboard = SDL_GetKeyboardState(NULL);
            if (!ConsumeKeyAndText(SDL_KEYDOWN, SDL_SCANCODE_E, 1) ||
                keyboard[SDL_SCANCODE_E] == 0) {
                result = 5;
            }
            [NSApp sendEvent:up];
            SDL_PumpEvents();
            keyboard = SDL_GetKeyboardState(NULL);
            if (!ConsumeKeyAndText(SDL_KEYUP, SDL_SCANCODE_E, 0) ||
                keyboard[SDL_SCANCODE_E] != 0) {
                result = 6;
            }
            down = MakeKeyEvent(native, NSKeyDown, arrow, arrow);
            up = MakeKeyEvent(native, NSKeyUp, arrow, arrow);
            if (result == 0 && (down == nil || up == nil)) {
                result = 7;
            }
            if (result == 0) {
                [NSApp sendEvent:down];
                SDL_PumpEvents();
                keyboard = SDL_GetKeyboardState(NULL);
                if (!ConsumeKeyAndText(SDL_KEYDOWN, SDL_SCANCODE_UP, 0) ||
                    keyboard[SDL_SCANCODE_UP] == 0) {
                    result = 8;
                }
            }
            if (result == 0) {
                [NSApp sendEvent:up];
                SDL_PumpEvents();
                keyboard = SDL_GetKeyboardState(NULL);
                if (!ConsumeKeyAndText(SDL_KEYUP, SDL_SCANCODE_UP, 0) ||
                    keyboard[SDL_SCANCODE_UP] != 0) {
                    result = 9;
                }
            }
            SDL_StopTextInput();
        }
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-text-events-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-final-archive-text-events-smoke: PASS UTF-8 text plus E/up key press/release\n");
    return 0;
}
