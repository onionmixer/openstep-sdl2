/* Record raw OPENSTEP AppKit input selectors before SDL translates them.
   This distinguishes an absent right/F1 event from an SDL mapping defect. */
#import <AppKit/AppKit.h>

#include <stdio.h>

@interface OPENSTEPInputRecordView : NSView
@end

@implementation OPENSTEPInputRecordView
- (BOOL)acceptsFirstResponder
{
    return YES;
}
- (void)record:(const char *)name event:(NSEvent *)event
{
    unsigned type = [event type];

    /* NSEvent documents characters/keyCode as key-event-only accessors.
       Calling either from a mouse handler raises an exception, which made
       the previous probe unable to establish whether mouse events arrived. */
    if (type == NSKeyDown || type == NSKeyUp) {
        NSString *characters = [event characters];
        unsigned first = [characters length] ? (unsigned)[characters characterAtIndex:0] : 0;
        printf("AppKit %s type=%u keyCode=%u character=0x%04x flags=0x%08x\n",
               name, type, [event keyCode], first, [event modifierFlags]);
    } else if (type == NSLeftMouseDown || type == NSLeftMouseUp ||
               type == NSRightMouseDown || type == NSRightMouseUp ||
               type == NSMouseMoved || type == NSLeftMouseDragged ||
               type == NSRightMouseDragged) {
        NSPoint point = [event locationInWindow];
        printf("AppKit %s type=%u location=%.1f,%.1f clicks=%d flags=0x%08x\n",
               name, type, point.x, point.y, [event clickCount],
               [event modifierFlags]);
    } else if (type == NSFlagsChanged) {
        printf("AppKit %s type=%u keyCode=%u flags=0x%08x\n",
               name, type, [event keyCode], [event modifierFlags]);
    } else {
        printf("AppKit %s type=%u flags=0x%08x\n",
               name, type, [event modifierFlags]);
    }
    fflush(stdout);
}
- (void)mouseDown:(NSEvent *)event { [self record:"mouseDown" event:event]; }
- (void)mouseUp:(NSEvent *)event { [self record:"mouseUp" event:event]; }
- (void)rightMouseDown:(NSEvent *)event { [self record:"rightMouseDown" event:event]; }
- (void)rightMouseUp:(NSEvent *)event { [self record:"rightMouseUp" event:event]; }
- (void)mouseMoved:(NSEvent *)event { [self record:"mouseMoved" event:event]; }
- (void)leftMouseDragged:(NSEvent *)event { [self record:"leftMouseDragged" event:event]; }
- (void)rightMouseDragged:(NSEvent *)event { [self record:"rightMouseDragged" event:event]; }
- (void)flagsChanged:(NSEvent *)event { [self record:"flagsChanged" event:event]; }
- (void)helpRequested:(NSEvent *)event { [self record:"helpRequested" event:event]; }
- (void)keyDown:(NSEvent *)event
{
    NSString *characters;
    unsigned first;

    [self record:"keyDown" event:event];
    characters = [event characters];
    first = [characters length] ? (unsigned)[characters characterAtIndex:0] : 0;
    if (first == 27) {
        [[self window] orderOut:nil];
        [NSApp stop:nil];
    }
}
@end

int main(void)
{
    NSAutoreleasePool *pool;
    NSWindow *window;
    OPENSTEPInputRecordView *view;

    if (!freopen("/tmp/SDL20/log/openstep-appkit-input-record.log", "w", stdout)) {
        return 1;
    }
    pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    [NSApp finishLaunching];
    [NSApp activateIgnoringOtherApps:YES];
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 480, 180)
                                         styleMask:NSTitledWindowMask | NSClosableWindowMask
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    view = [[OPENSTEPInputRecordView alloc] initWithFrame:NSMakeRect(0, 0, 480, 180)];
    if (!window || !view) {
        [view release];
        [window release];
        [pool release];
        return 2;
    }
    [window setTitle:@"OPENSTEP raw input record -- right click, F1, Escape"];
    [window setContentView:view];
    [window center];
    [window setAcceptsMouseMovedEvents:YES];
    [window makeKeyAndOrderFront:nil];
    if (![window makeFirstResponder:view]) {
        fprintf(stderr, "openstep-appkit-input-record-probe: cannot make view first responder\n");
        [view release];
        [window release];
        [pool release];
        return 3;
    }
    printf("openstep-appkit-input-record-probe: ready\n");
    fflush(stdout);
    [NSApp run];
    [view release];
    [window release];
    printf("openstep-appkit-input-record-probe: PASS\n");
    [pool release];
    return 0;
}
