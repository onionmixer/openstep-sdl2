/* Exercise the real OPENSTEP view's drop implementation without a file manager.
   A private pasteboard and NSDraggingInfo mock supply text and two filenames,
   including UTF-8 U+00E9. Each SDL queue sequence must have BEGIN, payload, COMPLETE. */
#import <AppKit/AppKit.h>

#include <stdio.h>

#include "SDL.h"

@interface SDLDropInfo : NSObject <NSDraggingInfo>
{
    NSPasteboard *_pasteboard;
}
- (id)initWithPasteboard:(NSPasteboard *)pasteboard;
@end

@implementation SDLDropInfo
- (id)initWithPasteboard:(NSPasteboard *)pasteboard
{
    self = [super init];
    if (self) _pasteboard = [pasteboard retain];
    return self;
}
- (void)dealloc
{
    [_pasteboard release];
    [super dealloc];
}
- (NSWindow *)draggingDestinationWindow { return nil; }
- (unsigned int)draggingSourceOperationMask { return NSDragOperationCopy; }
- (NSPoint)draggingLocation { return NSMakePoint(0.0, 0.0); }
- (NSPoint)draggedImageLocation { return NSMakePoint(0.0, 0.0); }
- (NSImage *)draggedImage { return nil; }
- (NSPasteboard *)draggingPasteboard { return _pasteboard; }
- (id)draggingSource { return nil; }
- (int)draggingSequenceNumber { return 1; }
- (void)slideDraggedImageTo:(NSPoint)screenPoint { (void)screenPoint; }
@end

@interface NSView (SDLDropSmoke)
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
@end

static NSString *StringFromUTF8(const char *text)
{
    NSData *data;
    NSString *string;

    data = [[NSData alloc] initWithBytes:text length:(unsigned)SDL_strlen(text)];
    if (data == nil) return nil;
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [data release];
    return string;
}

static int CheckDropEvents(const char *first_path, const char *second_path)
{
    SDL_Event event;
    int state = 0;

    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_DROPBEGIN) {
            if (state != 0) return 1;
            state = 1;
        } else if (event.type == SDL_DROPFILE) {
            const char *expected = (state == 1) ? first_path :
                                   (state == 2) ? second_path : NULL;
            if (expected == NULL || event.drop.file == NULL ||
                SDL_strcmp(event.drop.file, expected) != 0) {
                SDL_free(event.drop.file);
                return 2;
            }
            SDL_free(event.drop.file);
            ++state;
        } else if (event.type == SDL_DROPCOMPLETE) {
            if (state != 3) return 3;
            state = 4;
        }
    }
    return (state == 4) ? 0 : 4;
}

static int CheckTextDropEvents(const char *expected_text)
{
    SDL_Event event;
    int state = 0;

    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_DROPBEGIN) {
            if (state != 0) return 1;
            state = 1;
        } else if (event.type == SDL_DROPTEXT) {
            if (state != 1 || event.drop.file == NULL ||
                SDL_strcmp(event.drop.file, expected_text) != 0) {
                SDL_free(event.drop.file);
                return 2;
            }
            SDL_free(event.drop.file);
            state = 2;
        } else if (event.type == SDL_DROPCOMPLETE) {
            if (state != 2) return 3;
            state = 3;
        }
    }
    return (state == 3) ? 0 : 4;
}

int main(void)
{
    static const char first_path[] = "/tmp/SDL20/\303\251-drop";
    static const char second_path[] = "/tmp/SDL20/plain-drop";
    static const char drop_text[] = "OPENSTEP SDL2 \303\251 text";
    SDL_Window *window = NULL;
    NSWindow *native;
    NSView *view;
    NSPasteboard *pasteboard = nil;
    SDLDropInfo *info = nil;
    NSString *first = nil;
    NSString *second = nil;
    NSString *text = nil;
    NSArray *files;
    SDL_Event event;
    int result = 0;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    window = SDL_CreateWindow("SDL2 OPENSTEP drop smoke", SDL_WINDOWPOS_UNDEFINED,
                              SDL_WINDOWPOS_UNDEFINED, 96, 64, SDL_WINDOW_SHOWN);
    if (window == NULL) {
        result = 2;
        goto done;
    }
    SDL_EventState(SDL_DROPFILE, SDL_DISABLE);
    SDL_EventState(SDL_DROPTEXT, SDL_DISABLE);
    SDL_PumpEvents();
    native = [NSApp keyWindow];
    if (native == nil) native = [NSApp mainWindow];
    view = native ? [native contentView] : nil;
    first = StringFromUTF8(first_path);
    second = StringFromUTF8(second_path);
    pasteboard = [NSPasteboard pasteboardWithUniqueName];
    if (view == nil || first == nil || second == nil || pasteboard == nil) {
        result = 3;
        goto done;
    }
    info = [[SDLDropInfo alloc] initWithPasteboard:pasteboard];
    if (info == nil ||
        [pasteboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil] < 0 ||
        !(files = [NSArray arrayWithObjects:first, second, nil]) ||
        ![pasteboard setPropertyList:files forType:NSFilenamesPboardType]) {
        result = 4;
        goto done;
    }
    if ([view draggingEntered:info] != NSDragOperationNone ||
        [view prepareForDragOperation:info] || [view performDragOperation:info]) {
        result = 5;
        goto done;
    }

    /* OPENSTEP's pasteboard server permits one declared representation per
       private board in this environment.  Use independent boards just as
       real external drag sources do, rather than redeclaring a live source. */
    [info release];
    info = nil;
    [pasteboard releaseGlobally];
    pasteboard = [NSPasteboard pasteboardWithUniqueName];
    text = StringFromUTF8(drop_text);
    SDL_EventState(SDL_DROPTEXT, SDL_ENABLE);
    if (pasteboard == nil || text == nil ||
        [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil] < 0 ||
        ![pasteboard setString:text forType:NSStringPboardType] ||
        !(info = [[SDLDropInfo alloc] initWithPasteboard:pasteboard]) ||
        [view draggingEntered:info] != NSDragOperationCopy || ![view prepareForDragOperation:info]) {
        result = 6;
        goto done;
    }
    while (SDL_PollEvent(&event)) { }
    if (![view performDragOperation:info]) {
        result = 7;
        goto done;
    }
    SDL_PumpEvents();
    result = CheckTextDropEvents(drop_text);
    if (result != 0) {
        result += 10;
        goto done;
    }

    [info release];
    info = nil;
    [pasteboard releaseGlobally];
    pasteboard = [NSPasteboard pasteboardWithUniqueName];
    SDL_EventState(SDL_DROPFILE, SDL_ENABLE);
    if (pasteboard == nil ||
        [pasteboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil] < 0 ||
        ![pasteboard setPropertyList:files forType:NSFilenamesPboardType] ||
        !(info = [[SDLDropInfo alloc] initWithPasteboard:pasteboard]) ||
        [view draggingEntered:info] != NSDragOperationCopy ||
        ![view prepareForDragOperation:info]) {
        result = 8;
        goto done;
    }
    while (SDL_PollEvent(&event)) { }
    if (![view performDragOperation:info]) {
        result = 9;
        goto done;
    }
    SDL_PumpEvents();
    result = CheckDropEvents(first_path, second_path);

done:
    [info release];
    [pasteboard releaseGlobally];
    [first release];
    [second release];
    [text release];
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-dropfile-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-final-archive-dropfile-smoke: PASS utf8 TEXT+FILE+FILE sequences\n");
    return 0;
}
