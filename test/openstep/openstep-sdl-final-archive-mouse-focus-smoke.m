/* Validate OPENSTEP tracking-responder mouse focus without a physical pointer.
   OpenStep's mouse-event factory intentionally rejects synthetic tracking
   types, so this supplies a documented NSMouseMoved location object directly
   to the real content view's tracking selectors and verifies SDL focus/state. */
#import <AppKit/AppKit.h>

#include <stdio.h>

#include "SDL.h"

@interface NSView (SDLTrackingSmoke)
- (void)mouseEntered:(NSEvent *)event;
- (void)mouseExited:(NSEvent *)event;
@end

static NSEvent *MakeLocationEvent(NSWindow *window, NSPoint point)
{
    return [NSEvent mouseEventWithType:NSMouseMoved location:point modifierFlags:0
                             timestamp:0.0 windowNumber:[window windowNumber]
                               context:nil eventNumber:1 clickCount:0 pressure:0.0];
}

int main(void)
{
    SDL_Window *window;
    NSWindow *native;
    NSView *view;
    NSEvent *entered;
    NSEvent *exited;
    SDL_Event event;
    int mouse_x;
    int mouse_y;
    int result = 0;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 OPENSTEP mouse focus smoke",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              96, 64, SDL_WINDOW_SHOWN);
    if (window == NULL) {
        SDL_Quit();
        return 2;
    }
    SDL_PumpEvents();
    native = [NSApp keyWindow];
    if (native == nil) native = [NSApp mainWindow];
    view = native ? [native contentView] : nil;
    /* NSEvent locations use the native bottom-left base system; the SDL view
       converts this through its flipped content coordinate system. */
    entered = native ? MakeLocationEvent(native, NSMakePoint(12.0, 55.0)) : nil;
    exited = native ? MakeLocationEvent(native, NSMakePoint(120.0, 90.0)) : nil;
    if (view == nil || entered == nil || exited == nil) {
        result = 3;
    } else {
        while (SDL_PollEvent(&event)) { }
        [view mouseExited:exited];
        SDL_PumpEvents();
        if (SDL_GetMouseFocus() != NULL) {
            result = 4;
        } else {
            [view mouseEntered:entered];
            SDL_PumpEvents();
            if (SDL_GetMouseFocus() != window) {
                result = 5;
            } else {
                SDL_GetMouseState(&mouse_x, &mouse_y);
                if (mouse_x < 0 || mouse_x >= 96 || mouse_y < 0 || mouse_y >= 64) {
                    result = 6;
                }
            }
        }
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-mouse-focus-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-final-archive-mouse-focus-smoke: PASS enter+exit focus+motion\n");
    return 0;
}
