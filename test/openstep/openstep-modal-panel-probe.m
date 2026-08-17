/* Verify the OPENSTEP 4.2 primitive needed for a safe SDL message-box
   backend. This intentionally does not use NSRunAlertPanel: the probe tests
   a panel-owned button action that stops its own modal run loop. */
#import <AppKit/AppKit.h>

#include <stdio.h>

@interface OPENSTEPModalProbeTarget : NSObject
{
    int selected;
}
- (id)init;
- (void)choose:(id)sender;
- (int)selected;
@end

@implementation OPENSTEPModalProbeTarget
- (id)init
{
    self = [super init];
    if (self) selected = -1;
    return self;
}
- (void)choose:(id)sender
{
    selected = [sender tag];
    printf("openstep-modal-panel-probe: action selected=%d\n", selected);
    fflush(stdout);
}
- (int)selected
{
    return selected;
}
@end

int main(void)
{
    NSAutoreleasePool *pool;
    NSPanel *panel;
    NSButton *continue_button;
    NSButton *cancel_button;
    OPENSTEPModalProbeTarget *target;
    NSModalSession session;
    int response;

    if (!freopen("/tmp/SDL20/log/openstep-modal-panel-probe.log", "w", stdout)) {
        return 4;
    }
    pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    [NSApp finishLaunching];
    [NSApp activateIgnoringOtherApps:YES];
    target = [[OPENSTEPModalProbeTarget alloc] init];
    panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 300, 105)
                                        styleMask:NSTitledWindowMask
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
    if (!target || !panel) {
        [panel release];
        [target release];
        [pool release];
        return 1;
    }
    [panel setTitle:@"SDL2 OPENSTEP modal panel probe"];
    continue_button = [[NSButton alloc] initWithFrame:NSMakeRect(170, 18, 110, 30)];
    cancel_button = [[NSButton alloc] initWithFrame:NSMakeRect(50, 18, 110, 30)];
    if (!continue_button || !cancel_button) {
        [continue_button release];
        [cancel_button release];
        [panel release];
        [target release];
        [pool release];
        return 2;
    }
    [continue_button setTitle:@"Continue"];
    [continue_button setTag:71];
    [continue_button setTarget:target];
    [continue_button setAction:@selector(choose:)];
    [cancel_button setTitle:@"Cancel"];
    [cancel_button setTag:72];
    [cancel_button setTarget:target];
    [cancel_button setAction:@selector(choose:)];
    [[panel contentView] addSubview:continue_button];
    [[panel contentView] addSubview:cancel_button];
    [continue_button release];
    [cancel_button release];
    [panel center];
    fprintf(stdout, "openstep-modal-panel-probe: click Continue or Cancel\n");
    fflush(stdout);
    /* OPENSTEP documents modal sessions as the form of a modal loop that
       lets an application process between event dispatches.  GCD delivers
       button actions but its runModalForWindow: loop ignores stopModal, so
       use the documented session primitive and end our loop on the action's
       recorded selection. */
    session = [NSApp beginModalSessionForWindow:panel];
    if (session == NULL) {
        fprintf(stderr, "openstep-modal-panel-probe: cannot begin modal session\n");
        [panel release];
        [target release];
        [pool release];
        return 3;
    }
    while ([target selected] == -1) {
        [NSApp runModalSession:session];
    }
    response = [target selected];
    [NSApp endModalSession:session];
    [panel orderOut:nil];
    [panel release];
    [target release];
    [pool release];
    if (response != 71 && response != 72) {
        fprintf(stderr, "openstep-modal-panel-probe: unexpected response %d\n", response);
        return 4;
    }
    printf("openstep-modal-panel-probe: PASS selected=%d\n", response);
    return 0;
}
