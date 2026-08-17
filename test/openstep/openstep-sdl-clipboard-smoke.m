/* Verify SDL's OPENSTEP clipboard callbacks against the actual general
   NSPasteboard. The original public types/data are restored before exit. */
#import <AppKit/AppKit.h>

#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>
#include <string.h>

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
    const char *value = "SDL2 OPENSTEP UTF-8: \303\251 \342\230\203";
    const char *replacement = "native Pasteboard replacement";
    NSPasteboard *pasteboard;
    NSArray *saved_types;
    NSMutableDictionary *saved_data;
    NSArray *text_type;
    NSString *native_string;
    NSString *replacement_string;
    NSData *native_data;
    char *text;
    unsigned i;
    int result = 0;

    SDL_SetMainReady();
    SDL_InitMainThread();
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

    if (SDL_SetClipboardText(value) != 0 || !SDL_HasClipboardText()) {
        result = 4;
        goto done;
    }
    text = SDL_GetClipboardText();
    if (!text || strcmp(text, value) != 0) {
        SDL_free(text);
        result = 5;
        goto done;
    }
    SDL_free(text);

    native_string = [pasteboard stringForType:NSStringPboardType];
    native_data = native_string ? [native_string dataUsingEncoding:NSUTF8StringEncoding] : nil;
    if (!native_data || [native_data length] != strlen(value) ||
        memcmp([native_data bytes], value, strlen(value)) != 0) {
        result = 6;
        goto done;
    }

    replacement_string = [[NSString alloc] initWithCString:replacement];
    text_type = [[NSArray alloc] initWithObjects:NSStringPboardType, nil];
    if (!replacement_string || !text_type ||
        [pasteboard declareTypes:text_type owner:nil] < 0 ||
        ![pasteboard setString:replacement_string forType:NSStringPboardType]) {
        [replacement_string release];
        [text_type release];
        result = 7;
        goto done;
    }
    [replacement_string release];
    [text_type release];
    text = SDL_GetClipboardText();
    if (!text || strcmp(text, replacement) != 0) {
        SDL_free(text);
        result = 8;
        goto done;
    }
    SDL_free(text);

done:
    restore_pasteboard(pasteboard, saved_types, saved_data);
    [saved_data release];
    [saved_types release];
    SDL_Quit();
    if (result) {
        fprintf(stderr, "openstep-sdl-clipboard-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-clipboard-smoke: PASS native UTF-8 round-trip and restore\n");
    return 0;
}
