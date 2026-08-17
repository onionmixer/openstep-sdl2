/* Verify that SDL_SetWindowTitle preserves UTF-8 at the native AppKit edge.
   This uses a real SDL window, runs a bounded event-pump loop, then exits. */
#import <AppKit/AppKit.h>

#include <stdio.h>

#include "SDL.h"

static int TitleMatchesUTF8(NSString *title)
{
    NSData *data;
    const unsigned char *bytes;
    static const unsigned char expected[] = {
        'S', 'D', 'L', '2', ' ', 0xc3, 0xa9, ' ', 0xe2, 0x98, 0x83
    };

    data = [title dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil || [data length] != sizeof(expected)) return 0;
    bytes = (const unsigned char *)[data bytes];
    return SDL_memcmp(bytes, expected, sizeof(expected)) == 0;
}

int main(void)
{
    SDL_Window *window;
    NSWindow *native;
    int i;
    int result = 0;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 title", SDL_WINDOWPOS_UNDEFINED,
                              SDL_WINDOWPOS_UNDEFINED, 96, 64,
                              SDL_WINDOW_SHOWN);
    if (window == NULL) {
        SDL_Quit();
        return 2;
    }
    SDL_SetWindowTitle(window, "SDL2 \303\251 \342\230\203");
    for (i = 0; i < 128; ++i) SDL_PumpEvents();
    native = [NSApp keyWindow];
    if (native == nil) native = [NSApp mainWindow];
    if (native == nil) {
        result = 3;
    } else if (!TitleMatchesUTF8([native title])) {
        result = 4;
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-utf8-title-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-final-archive-utf8-title-smoke: PASS UTF-8 title plus bounded event pumps\n");
    return 0;
}
