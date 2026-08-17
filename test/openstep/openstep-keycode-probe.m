/* Run from an OPENSTEP GUI Terminal to record native physical key codes. */
#import <AppKit/AppKit.h>

@interface SDL20KeyProbeView : NSView
@end

@implementation SDL20KeyProbeView
- (BOOL)acceptsFirstResponder
{
    return YES;
}
- (void)keyDown:(NSEvent *)event
{
    NSString *characters = [event characters];
    NSString *unmodified = [event charactersIgnoringModifiers];
    unsigned int first = [characters length] ? [characters characterAtIndex:0] : 0;
    unsigned int unmodified_first = [unmodified length] ? [unmodified characterAtIndex:0] : 0;
    printf("KEY down keyCode=%u character=0x%04x unmodified=0x%04x flags=0x%08x repeat=%u\n",
           [event keyCode], first, unmodified_first, [event modifierFlags],
           [event isARepeat] ? 1 : 0);
    fflush(stdout);
    if (first == 27) {
        [NSApp terminate:nil];
    }
}
- (void)keyUp:(NSEvent *)event
{
    printf("KEY up keyCode=%u flags=0x%08x\n", [event keyCode], [event modifierFlags]);
    fflush(stdout);
}
- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    [NSApp terminate:nil];
}
@end

int main(int argc, char **argv)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSWindow *window;
    SDL20KeyProbeView *view;

    [NSApplication sharedApplication];
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(80, 80, 480, 160)
                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                           backing:NSBackingStoreBuffered defer:NO];
    view = [[SDL20KeyProbeView alloc] initWithFrame:NSMakeRect(0, 0, 480, 160)];
    [window setTitle:@"SDL2 OPENSTEP keyboard keycode probe — Esc/close exits"];
    [window setContentView:view];
    [window setDelegate:view];
    [window makeFirstResponder:view];
    [window makeKeyAndOrderFront:nil];
    [NSApp run];
    [pool release];
    return 0;
}
