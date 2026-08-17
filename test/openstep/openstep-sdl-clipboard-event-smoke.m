/* Verify that an external AppKit pasteboard change reaches SDL as the public
   SDL_CLIPBOARDUPDATE event. The pre-test public pasteboard data is restored. */
#import <AppKit/AppKit.h>

#include "SDL.h"
#include <stdio.h>

static void restore_pasteboard(NSPasteboard *pasteboard, NSArray *types,
                               NSMutableDictionary *saved_data)
{
    unsigned i;

    if (!pasteboard || !types) return;
    [pasteboard declareTypes:types owner:nil];
    for (i = 0; i < [types count]; ++i) {
        NSString *type = [types objectAtIndex:i];
        NSData *data = [saved_data objectForKey:type];
        if (data) [pasteboard setData:data forType:type];
    }
}

int main(void)
{
    NSPasteboard *pasteboard;
    NSArray *saved_types;
    NSMutableDictionary *saved_data;
    NSArray *text_type;
    NSString *replacement;
    SDL_Event event;
    unsigned i;
    int got_update = 0;
    int result = 0;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    pasteboard = [NSPasteboard generalPasteboard];
    if (!pasteboard) {
        SDL_Quit();
        return 2;
    }
    saved_types = [[pasteboard types] retain];
    saved_data = [[NSMutableDictionary alloc] initWithCapacity:[saved_types count]];
    if (!saved_types || !saved_data) {
        [saved_types release];
        [saved_data release];
        SDL_Quit();
        return 3;
    }
    for (i = 0; i < [saved_types count]; ++i) {
        NSString *type = [saved_types objectAtIndex:i];
        NSData *data = [pasteboard dataForType:type];
        if (data) [saved_data setObject:data forKey:type];
    }

    while (SDL_PollEvent(&event)) { }
    replacement = [[NSString alloc] initWithCString:"OPENSTEP external clipboard event"];
    text_type = [[NSArray alloc] initWithObjects:NSStringPboardType, nil];
    if (!replacement || !text_type ||
        [pasteboard declareTypes:text_type owner:nil] < 0 ||
        ![pasteboard setString:replacement forType:NSStringPboardType]) {
        result = 4;
    }
    [replacement release];
    [text_type release];
    if (!result) {
        SDL_PumpEvents();
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_CLIPBOARDUPDATE) got_update = 1;
        }
        if (!got_update) result = 5;
    }

    restore_pasteboard(pasteboard, saved_types, saved_data);
    [saved_data release];
    [saved_types release];
    SDL_Quit();
    if (result) {
        fprintf(stderr, "openstep-sdl-clipboard-event-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-clipboard-event-smoke: PASS external change event and restore\n");
    return 0;
}
