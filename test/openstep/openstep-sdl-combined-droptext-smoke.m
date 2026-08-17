/* Physical AppKit text-drag source plus SDL2 text-drop target in one process.
   OPENSTEP Edit.app does not expose a selected-text drag source, so this probe
   uses only documented AppKit NSView dragImage: and NSPasteboard APIs. */
#import <AppKit/AppKit.h>

#include <stdio.h>

#include "SDL.h"

@interface SDLTextDragSourceView : NSView
@end

@implementation SDLTextDragSourceView
- (BOOL)isFlipped
{
    return YES;
}
- (BOOL)acceptsFirstResponder
{
    return YES;
}
- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    /* A source window can be behind the SDL target when the user begins the
       first physical drag.  OPENSTEP otherwise consumes that first click to
       activate the source window, so no mouseDown: and no drag starts until a
       second attempt.  This probe intentionally accepts that first click. */
    (void)event;
    return YES;
}
- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)local
{
    /* Required NSDragging source callback on OPENSTEP 4.2.  The source offers
       a normal copy of its private NSString pasteboard payload whether the
       destination is local (the SDL target view) or external. */
    (void)local;
    return NSDragOperationCopy;
}
- (void)drawRect:(NSRect)rect
{
    (void)rect;

    /* This is deliberately drawn by the same minimal AppKit path proven by
       the completed SDL 1.2 port.  A plain NSView otherwise appears as an
       ambiguous empty grey panel on the physical OPENSTEP console. */
    [[NSColor colorWithCalibratedRed:0.10 green:0.22 blue:0.48 alpha:1.0] set];
    NSRectFill([self bounds]);
    [[NSColor whiteColor] set];
    [@"SDL_DROPTEXT physical source" drawAtPoint:NSMakePoint(18.0, 16.0)
                                  withAttributes:nil];
    [@"Click and drag this blue area into the SDL target window." drawAtPoint:NSMakePoint(18.0, 42.0)
                                                             withAttributes:nil];
    [@"Payload: SDL2 physical text e-acute" drawAtPoint:NSMakePoint(18.0, 68.0)
                                           withAttributes:nil];
}
- (void)mouseDown:(NSEvent *)event
{
    static const char payload_utf8[] = "SDL2 physical text \303\251";
    NSData *data;
    NSString *text;
    NSPasteboard *pasteboard;
    NSImage *image;
    NSPoint point;

    printf("openstep-sdl-combined-droptext-smoke: source mouseDown\n");
    fflush(stdout);

    data = [NSData dataWithBytes:payload_utf8 length:sizeof(payload_utf8) - 1];
    text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    pasteboard = [NSPasteboard pasteboardWithUniqueName];
    if (text == nil || pasteboard == nil ||
        [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil] < 0 ||
        ![pasteboard setString:text forType:NSStringPboardType]) {
        [text release];
        return;
    }
    image = [[NSImage alloc] initWithSize:NSMakeSize(180.0, 28.0)];
    if (image == nil) {
        [text release];
        return;
    }
    /* OPENSTEP's drag manager requires an image with its own cached window;
       an allocated-but-empty NSImage triggers its documented assertion that
       no global window number is available.  setCachedSeparately:, followed
       by an actual lockFocus drawing pass, creates that cache using only the
       OPENSTEP 4.2 NSImage public API. */
    [image setCachedSeparately:YES];
    [image lockFocus];
    [[NSColor colorWithCalibratedRed:0.85 green:0.90 blue:1.00 alpha:1.0] set];
    NSRectFill(NSMakeRect(0.0, 0.0, 180.0, 28.0));
    [[NSColor blackColor] set];
    [@"SDL2 text" drawAtPoint:NSMakePoint(8.0, 7.0) withAttributes:nil];
    [image unlockFocus];
    [image recache];
    point = [self convertPoint:[event locationInWindow] fromView:nil];
    [self dragImage:image at:point offset:NSMakeSize(0.0, 0.0) event:event
          pasteboard:pasteboard source:self slideBack:YES];
    [image release];
    [text release];
}
- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)screenPoint deposited:(BOOL)flag
{
    (void)image;
    (void)screenPoint;
    printf("openstep-sdl-combined-droptext-smoke: source deposited=%d\n", flag ? 1 : 0);
    fflush(stdout);
}
@end

static int fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-combined-droptext-smoke: %s: %s\n", what, SDL_GetError());
    fflush(stdout);
    return 1;
}

static void print_text_bytes(const char *text)
{
    unsigned int i;

    printf("openstep-sdl-combined-droptext-smoke: text=%s\n", text);
    printf("openstep-sdl-combined-droptext-smoke: bytes");
    for (i = 0; text[i] != '\0'; ++i) {
        printf(" %02x", (unsigned int)(unsigned char)text[i]);
    }
    printf("\n");
    fflush(stdout);
}

int main(void)
{
    SDL_Window *window = NULL;
    SDL_Event event;
    NSWindow *source_window = nil;
    SDLTextDragSourceView *source_view = nil;
    Uint32 deadline;
    int saw_begin = 0;
    int saw_text = 0;
    int saw_complete = 0;
    int result = 0;

    if (!freopen("/tmp/SDL20/log/openstep-sdl-combined-droptext-record.log", "w", stdout)) {
        return 2;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    window = SDL_CreateWindow("SDL target: drop text here (5 minutes)",
                              54, 54, 380, 130, 0);
    if (window == NULL) {
        SDL_Quit();
        return fail("target window creation failed");
    }
    SDL_EventState(SDL_DROPFILE, SDL_DISABLE);
    SDL_EventState(SDL_DROPTEXT, SDL_DISABLE);
    SDL_EventState(SDL_DROPTEXT, SDL_ENABLE);
    source_window = [[NSWindow alloc] initWithContentRect:NSMakeRect(54, 250, 380, 100)
                                                 styleMask:NSTitledWindowMask | NSClosableWindowMask
                                                   backing:NSBackingStoreBuffered defer:NO];
    source_view = [[SDLTextDragSourceView alloc] initWithFrame:NSMakeRect(0, 0, 380, 100)];
    if (source_window == nil || source_view == nil) {
        result = fail("AppKit drag-source creation failed");
        goto done;
    }
    [source_window setTitle:@"Drag from this window to SDL target: SDL2 physical text e-acute"];
    [source_window setContentView:source_view];
    [source_window setAcceptsMouseMovedEvents:YES];
    [source_window makeFirstResponder:source_view];
    [source_window makeKeyAndOrderFront:nil];
    deadline = SDL_GetTicks() + 300000;
    while (!saw_complete && (Sint32)(deadline - SDL_GetTicks()) > 0) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_DROPBEGIN) {
                if (saw_begin || saw_text) {
                    result = fail("invalid duplicate SDL_DROPBEGIN ordering");
                    goto done;
                }
                saw_begin = 1;
            } else if (event.type == SDL_DROPTEXT) {
                if (!saw_begin || saw_text || !event.drop.file || !event.drop.file[0]) {
                    if (event.drop.file) SDL_free(event.drop.file);
                    result = fail("invalid SDL_DROPTEXT payload or ordering");
                    goto done;
                }
                print_text_bytes(event.drop.file);
                SDL_free(event.drop.file);
                saw_text = 1;
            } else if (event.type == SDL_DROPCOMPLETE) {
                if (!saw_begin || !saw_text) {
                    result = fail("invalid SDL_DROPCOMPLETE ordering");
                    goto done;
                }
                saw_complete = 1;
            } else if (event.type == SDL_QUIT) {
                result = fail("target window closed before drop completed");
                goto done;
            }
        }
        SDL_Delay(10);
    }
    if (!saw_complete) result = fail("timed out waiting for a text drop");

done:
    SDL_EventState(SDL_DROPFILE, SDL_ENABLE);
    [source_window orderOut:nil];
    [source_view release];
    [source_window release];
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) return result;
    printf("openstep-sdl-combined-droptext-smoke: PASS begin/text/complete sequence\n");
    fflush(stdout);
    return 0;
}
