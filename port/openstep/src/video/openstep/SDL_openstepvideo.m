/* SDL 2.32.10 OPENSTEP AppKit video driver -- native bootstrap/display slice. */
#import <AppKit/AppKit.h>
#import <AppKit/psopsNeXT.h>

#include <GL/gl.h>
#include <GL/osmesa.h>

#include "../../SDL_internal.h"
#include "../SDL_sysvideo.h"
#include "../../events/SDL_events_c.h"
#include "../../events/SDL_clipboardevents_c.h"
#include "../../events/SDL_dropevents_c.h"
#include "../../events/SDL_keyboard_c.h"
#include "../../events/SDL_mouse_c.h"
#include "../../events/SDL_windowevents_c.h"
#include "SDL_openstepvideo.h"
#include "SDL_openstepglpresent.h"

#define OPENSTEPVID_DRIVER_NAME "openstep"

static int OPENSTEP_VideoInit(_THIS);
static void OPENSTEP_VideoQuit(_THIS);
static void OPENSTEP_DeleteDevice(_THIS);
static void OPENSTEP_GetDisplayModes(_THIS, SDL_VideoDisplay *display);
static int OPENSTEP_CreateSDLWindow(_THIS, SDL_Window *window);
static void OPENSTEP_SetWindowTitle(_THIS, SDL_Window *window);
static void OPENSTEP_SetWindowIcon(_THIS, SDL_Window *window, SDL_Surface *icon);
static void OPENSTEP_SetWindowPosition(_THIS, SDL_Window *window);
static void OPENSTEP_SetWindowSize(_THIS, SDL_Window *window);
static void OPENSTEP_SetWindowMinimumSize(_THIS, SDL_Window *window);
static void OPENSTEP_SetWindowMaximumSize(_THIS, SDL_Window *window);
static int OPENSTEP_GetWindowBordersSize(_THIS, SDL_Window *window, int *top, int *left, int *bottom, int *right);
static int OPENSTEP_SetWindowInputFocus(_THIS, SDL_Window *window);
static void OPENSTEP_ShowWindow(_THIS, SDL_Window *window);
static void OPENSTEP_HideWindow(_THIS, SDL_Window *window);
static void OPENSTEP_RaiseWindow(_THIS, SDL_Window *window);
static void OPENSTEP_MaximizeWindow(_THIS, SDL_Window *window);
static void OPENSTEP_MinimizeWindow(_THIS, SDL_Window *window);
static void OPENSTEP_RestoreWindow(_THIS, SDL_Window *window);
static void OPENSTEP_SetWindowBordered(_THIS, SDL_Window *window, SDL_bool bordered);
static void OPENSTEP_SetWindowResizable(_THIS, SDL_Window *window, SDL_bool resizable);
static void OPENSTEP_SetWindowAlwaysOnTop(_THIS, SDL_Window *window, SDL_bool on_top);
static void OPENSTEP_SetWindowFullscreen(_THIS, SDL_Window *window,
                                         SDL_VideoDisplay *display, SDL_bool fullscreen);
static void OPENSTEP_DestroyWindow(_THIS, SDL_Window *window);
static int OPENSTEP_CreateWindowFramebuffer(_THIS, SDL_Window *window, Uint32 *format, void **pixels, int *pitch);
static int OPENSTEP_UpdateWindowFramebuffer(_THIS, SDL_Window *window, const SDL_Rect *rects, int numrects);
static void OPENSTEP_DestroyWindowFramebuffer(_THIS, SDL_Window *window);
static void OPENSTEP_PumpEvents(_THIS);
static int OPENSTEP_GL_LoadLibrary(_THIS, const char *path);
static void *OPENSTEP_GL_GetProcAddress(_THIS, const char *proc);
static void OPENSTEP_GL_UnloadLibrary(_THIS);
static SDL_GLContext OPENSTEP_GL_CreateContext(_THIS, SDL_Window *window);
static int OPENSTEP_GL_MakeCurrent(_THIS, SDL_Window *window, SDL_GLContext context);
static void OPENSTEP_GL_GetDrawableSize(_THIS, SDL_Window *window, int *w, int *h);
static int OPENSTEP_GL_SetSwapInterval(_THIS, int interval);
static int OPENSTEP_GL_GetSwapInterval(_THIS);
static int OPENSTEP_GL_SwapWindow(_THIS, SDL_Window *window);
static void OPENSTEP_GL_DeleteContext(_THIS, SDL_GLContext context);
/*
 * ONE STAMP OWNER PER PROCESS, and the driver is the reason.
 *
 * Its surface and its present flag are file statics over there -- one
 * mapped surface, one application array, one mode -- so turning the mode on
 * changes the whole process, not one window.  Two windows stamping would
 * each believe they owned a rectangle and the second would deliver the
 * first's picture.  So the backend keeps the lease itself.
 */
static SDL_Window *openstep_stamp_owner;

/* The direct video-memory stamp, whose lease every one of these must end.
 * Declared here because the lifecycle sites come before the definitions. */
static void OPENSTEP_GL_StampRelease(SDL_Window *window);
static void OPENSTEP_GL_StampReleaseOwner(void);
static void OPENSTEP_GL_DefaultProfileConfig(_THIS, int *mask, int *major, int *minor);
static int OPENSTEP_RebuildNativeWindow(_THIS, SDL_Window *window);
static SDL_Cursor *OPENSTEP_CreateDefaultCursor(void);
static SDL_Cursor *OPENSTEP_CreateCursor(SDL_Surface *surface, int hot_x, int hot_y);
static SDL_Cursor *OPENSTEP_CreateSystemCursor(SDL_SystemCursor id);
static int OPENSTEP_ShowCursor(SDL_Cursor *cursor);
static void OPENSTEP_FreeCursor(SDL_Cursor *cursor);
static void OPENSTEP_WarpMouse(SDL_Window *window, int x, int y);
static Uint32 OPENSTEP_GetGlobalMouseState(int *x, int *y);
static int OPENSTEP_SetClipboardText(_THIS, const char *text);
static char *OPENSTEP_GetClipboardText(_THIS);
static SDL_bool OPENSTEP_HasClipboardText(_THIS);
static void OPENSTEP_CheckClipboardUpdate(_THIS);
static void OPENSTEP_AcceptDragAndDrop(SDL_Window *window, SDL_bool accept);
static int OPENSTEP_ShowMessageBox(_THIS, const SDL_MessageBoxData *messageboxdata,
                                   int *buttonid);
static int OPENSTEP_ShowMessageBoxBootstrap(const SDL_MessageBoxData *messageboxdata,
                                            int *buttonid);

static unsigned int OPENSTEP_WindowStyle(SDL_Window *window)
{
    unsigned int style = 0;

    if ((window->flags & SDL_WINDOW_FULLSCREEN) ||
        (window->flags & SDL_WINDOW_BORDERLESS)) {
        return 0;
    }
    style = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask;
    if (window->flags & SDL_WINDOW_RESIZABLE) {
        style |= NSResizableWindowMask;
    }
    return style;
}

/* Mesa 3.4.2's static OSMesa build exports these internal glue functions.
   They are deliberately confined to this backend: public applications use
   only SDL_GL_GetProcAddress and never depend on Mesa-private symbols. */
extern const GLvoid *_glapi_get_proc_address(const char *funcName);
extern void gl_make_current(void *ctx, void *buffer);

typedef struct SDL_OpenStepGLContext
{
    OSMesaContext context;
    SDL_Window *window;
    SDL_OpenStepWindowData *window_data;
    void *pixels;
    size_t pixels_size;
    int width;
    int height;
    struct SDL_OpenStepGLContext *next;
} SDL_OpenStepGLContext;

typedef struct SDL_OpenStepCursorData
{
    NSCursor *cursor;
} SDL_OpenStepCursorData;

static NSCursor *OPENSTEP_CreateInvisibleCursor(void)
{
    NSBitmapImageRep *representation;
    NSImage *image;
    NSCursor *cursor;
    /* OPENSTEP may populate up to five plane slots even for a packed image. */
    unsigned char *planes[5];

    representation = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:16 pixelsHigh:16
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:64
        bitsPerPixel:32];
    if (representation == nil) return nil;
    [representation getBitmapDataPlanes:planes];
    SDL_memset(planes[0], 0, 16 * 16 * 4);
    image = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
    if (image == nil) {
        [representation release];
        return nil;
    }
    [image addRepresentation:representation];
    [representation release];
    cursor = [[NSCursor alloc] initWithImage:image hotSpot:NSMakePoint(0.0, 0.0)];
    [image release];
    return cursor;
}

static SDL_Cursor *OPENSTEP_WrapNativeCursor(NSCursor *native_cursor)
{
    SDL_Cursor *cursor;
    SDL_OpenStepCursorData *data;

    if (native_cursor == nil) return NULL;
    cursor = (SDL_Cursor *)SDL_calloc(1, sizeof(*cursor));
    data = (SDL_OpenStepCursorData *)SDL_calloc(1, sizeof(*data));
    if (!cursor || !data) {
        SDL_free(data);
        SDL_free(cursor);
        SDL_OutOfMemory();
        return NULL;
    }
    data->cursor = [native_cursor retain];
    cursor->driverdata = data;
    return cursor;
}

static SDL_Cursor *OPENSTEP_CreateDefaultCursor(void)
{
    return OPENSTEP_WrapNativeCursor([NSCursor arrowCursor]);
}

static SDL_Cursor *OPENSTEP_CreateSystemCursor(SDL_SystemCursor id)
{
    switch (id) {
    case SDL_SYSTEM_CURSOR_ARROW:
        return OPENSTEP_WrapNativeCursor([NSCursor arrowCursor]);
    case SDL_SYSTEM_CURSOR_IBEAM:
        return OPENSTEP_WrapNativeCursor([NSCursor IBeamCursor]);
    default:
        /* OPENSTEP 4.2 publicly exposes only arrow and I-beam system
           cursors.  Do not pretend that an unrelated arrow is a resize,
           wait, hand or forbidden cursor. */
        SDL_SetError("OPENSTEP has no matching native system cursor");
        return NULL;
    }
}

static SDL_Cursor *OPENSTEP_CreateCursor(SDL_Surface *surface, int hot_x, int hot_y)
{
    SDL_Cursor *cursor;
    SDL_OpenStepCursorData *data;
    NSBitmapImageRep *representation;
    NSImage *image;
    /* See OPENSTEP_CreateInvisibleCursor: this must provide five slots. */
    unsigned char *planes[5];
    Uint8 *pixels;
    int x, y;

    /* OPENSTEP's documented NXCursor representation is 16x16.  Refuse a
       larger colour cursor instead of silently cropping it: callers receive
       the normal SDL creation failure and retain their existing cursor. */
    if (!surface || surface->w <= 0 || surface->h <= 0 ||
        surface->w > 16 || surface->h > 16) {
        SDL_SetError("OPENSTEP native cursors are limited to 16x16 pixels");
        return NULL;
    }
    representation = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:16 pixelsHigh:16
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:64
        bitsPerPixel:32];
    if (representation == nil) {
        SDL_OutOfMemory();
        return NULL;
    }
    [representation getBitmapDataPlanes:planes];
    pixels = planes[0];
    SDL_memset(pixels, 0, 16 * 16 * 4);
    for (y = 0; y < surface->h; ++y) {
        Uint32 *source = (Uint32 *)((Uint8 *)surface->pixels + y * surface->pitch);
        for (x = 0; x < surface->w; ++x) {
            Uint8 red, green, blue, alpha;
            SDL_GetRGBA(source[x], surface->format, &red, &green, &blue, &alpha);
            pixels[(y * 16 + x) * 4] = red;
            pixels[(y * 16 + x) * 4 + 1] = green;
            pixels[(y * 16 + x) * 4 + 2] = blue;
            pixels[(y * 16 + x) * 4 + 3] = alpha;
        }
    }
    image = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
    if (image == nil) {
        [representation release];
        SDL_OutOfMemory();
        return NULL;
    }
    [image addRepresentation:representation];
    [representation release];
    data = (SDL_OpenStepCursorData *)SDL_calloc(1, sizeof(*data));
    cursor = (SDL_Cursor *)SDL_calloc(1, sizeof(*cursor));
    if (!data || !cursor) {
        [image release];
        SDL_free(cursor);
        SDL_free(data);
        SDL_OutOfMemory();
        return NULL;
    }
    data->cursor = [[NSCursor alloc] initWithImage:image
                                             hotSpot:NSMakePoint((float)hot_x, (float)hot_y)];
    [image release];
    if (data->cursor == nil) {
        SDL_free(cursor);
        SDL_free(data);
        SDL_OutOfMemory();
        return NULL;
    }
    cursor->driverdata = data;
    return cursor;
}

static void OPENSTEP_FreeCursor(SDL_Cursor *cursor)
{
    SDL_OpenStepCursorData *data;

    if (!cursor) return;
    data = (SDL_OpenStepCursorData *)cursor->driverdata;
    if (data) {
        if (data->cursor != nil) [data->cursor release];
        SDL_free(data);
    }
    SDL_free(cursor);
}

static int OPENSTEP_ShowCursor(SDL_Cursor *cursor)
{
    SDL_VideoDevice *device;
    SDL_OpenStepVideoData *video_data;
    SDL_Window *window;
    NSCursor *native_cursor;

    device = SDL_GetVideoDevice();
    if (!device) return SDL_SetError("OPENSTEP video device is unavailable");
    video_data = (SDL_OpenStepVideoData *)device->driverdata;
    native_cursor = nil;
    if (cursor && cursor->driverdata) {
        native_cursor = ((SDL_OpenStepCursorData *)cursor->driverdata)->cursor;
    } else if (video_data) {
        native_cursor = (NSCursor *)video_data->invisible_cursor;
        if (native_cursor == nil) {
            native_cursor = OPENSTEP_CreateInvisibleCursor();
            if (native_cursor == nil) return SDL_OutOfMemory();
            video_data->invisible_cursor = (void *)native_cursor;
        }
    }
    if (native_cursor == nil) return SDL_SetError("OPENSTEP could not create a native cursor");
    [native_cursor set];
    for (window = device->windows; window; window = window->next) {
        SDL_OpenStepWindowData *window_data = (SDL_OpenStepWindowData *)window->driverdata;
        if (window_data) {
            window_data->cursor = (void *)native_cursor;
            if (window_data->window && window_data->view) {
                [(NSWindow *)window_data->window
                    invalidateCursorRectsForView:(NSView *)window_data->view];
            }
        }
    }
    return 0;
}

static void OPENSTEP_WarpMouse(SDL_Window *window, int x, int y)
{
    SDL_OpenStepWindowData *data;

    if (!window || !window->driverdata) return;
    data = (SDL_OpenStepWindowData *)window->driverdata;
    if (!data->view) return;
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (window->w > 0 && x >= window->w) x = window->w - 1;
    if (window->h > 0 && y >= window->h) y = window->h - 1;
    /* The SDL view is flipped.  Its local Display PostScript coordinate
       system therefore matches SDL's documented upper-left window origin. */
    [(NSView *)data->view lockFocus];
    PSsetmouse((float)x, (float)y);
    [(NSView *)data->view unlockFocus];
    SDL_SendMouseMotion(window, 0, 0, x, y);
}

static Uint32 OPENSTEP_GetGlobalMouseState(int *x, int *y)
{
    SDL_Mouse *mouse;
    SDL_Window *window;
    SDL_OpenStepWindowData *data;
    NSPoint local_point;
    int ignored_x, ignored_y;
    Uint32 buttons;

    *x = 0;
    *y = 0;
    /* SDL_GetMouseState reads the mouse core directly; it does not invoke
       this global-state callback, so it is safe here and preserves buttons. */
    buttons = SDL_GetMouseState(&ignored_x, &ignored_y);
    mouse = SDL_GetMouse();
    window = mouse->focus;
    if (!window || !window->driverdata) return buttons;
    data = (SDL_OpenStepWindowData *)window->driverdata;
    if (!data->window || !data->view) return buttons;

    /* AppKit documents this as the current base-coordinate mouse position
       even when no event is pending.  In particular, the Display
       PostScript PScurrentmouse documentation says not to use that operator
       from an Application Kit application.  Convert this base-coordinate
       point through the flipped SDL view exactly as event locations are. */
    local_point = [(NSWindow *)data->window mouseLocationOutsideOfEventStream];
    local_point = [(NSView *)data->view convertPoint:local_point fromView:nil];
    *x = window->x + (int)local_point.x;
    *y = window->y + (int)local_point.y;
    return buttons;
}

/* NSPasteboard is the OPENSTEP system clipboard. SDL's public clipboard
   contract is UTF-8, while NSString's unqualified C-string methods use the
   user's legacy default encoding, so conversion is explicit here. */
static int OPENSTEP_SetClipboardText(_THIS, const char *text)
{
    SDL_OpenStepVideoData *video_data = (SDL_OpenStepVideoData *)_this->driverdata;
    NSPasteboard *pasteboard;
    NSString *string;
    NSData *utf8;
    NSArray *types;
    BOOL wrote;

    if (!text) text = "";
    utf8 = [[NSData alloc] initWithBytes:text length:(unsigned)SDL_strlen(text)];
    if (!utf8) return SDL_OutOfMemory();
    string = [[NSString alloc] initWithData:utf8 encoding:NSUTF8StringEncoding];
    [utf8 release];
    if (!string) return SDL_SetError("Clipboard text is not valid UTF-8");
    types = [[NSArray alloc] initWithObjects:NSStringPboardType, nil];
    if (!types) {
        [string release];
        return SDL_OutOfMemory();
    }
    pasteboard = [NSPasteboard generalPasteboard];
    if (!pasteboard || [pasteboard declareTypes:types owner:nil] < 0) {
        [types release];
        [string release];
        return SDL_SetError("OPENSTEP could not declare clipboard text type");
    }
    wrote = [pasteboard setString:string forType:NSStringPboardType];
    [types release];
    [string release];
    if (!wrote) return SDL_SetError("OPENSTEP could not set clipboard text");
    /* SDL_SetClipboardText is synchronous.  Consume this local pasteboard
       revision now, so PumpEvents only reports changes made outside SDL. */
    if (video_data) video_data->clipboard_count = [pasteboard changeCount];
    return 0;
}

static char *OPENSTEP_GetClipboardText(_THIS)
{
    NSPasteboard *pasteboard;
    NSArray *types;
    NSString *available;
    NSString *string;
    NSData *utf8;
    char *text;
    unsigned length;

    (void)_this;
    pasteboard = [NSPasteboard generalPasteboard];
    types = [[NSArray alloc] initWithObjects:NSStringPboardType, nil];
    if (!types) {
        SDL_OutOfMemory();
        return NULL;
    }
    available = pasteboard ? [pasteboard availableTypeFromArray:types] : nil;
    if (!available || ![available isEqualToString:NSStringPboardType]) {
        [types release];
        return SDL_strdup("");
    }
    string = [pasteboard stringForType:NSStringPboardType];
    [types release];
    if (!string) return SDL_strdup("");
    utf8 = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (!utf8) {
        SDL_SetError("OPENSTEP could not encode clipboard text as UTF-8");
        return SDL_strdup("");
    }
    length = [utf8 length];
    text = (char *)SDL_malloc((size_t)length + 1);
    if (!text) {
        SDL_OutOfMemory();
        return NULL;
    }
    if (length) SDL_memcpy(text, [utf8 bytes], length);
    text[length] = '\0';
    return text;
}

static SDL_bool OPENSTEP_HasClipboardText(_THIS)
{
    char *text = OPENSTEP_GetClipboardText(_this);
    SDL_bool has_text = SDL_FALSE;

    if (text) {
        has_text = text[0] ? SDL_TRUE : SDL_FALSE;
        SDL_free(text);
    }
    return has_text;
}

/* NSPasteboard has no OPENSTEP 4.2 notification API suitable for this
   backend, but its monotonically changing revision is public AppKit API.
   Compare it from PumpEvents, matching SDL's polling event model. */
static void OPENSTEP_CheckClipboardUpdate(_THIS)
{
    SDL_OpenStepVideoData *data = (SDL_OpenStepVideoData *)_this->driverdata;
    NSPasteboard *pasteboard;
    int count;

    if (!data) return;
    pasteboard = [NSPasteboard generalPasteboard];
    if (!pasteboard) return;
    count = [pasteboard changeCount];
    if (count != data->clipboard_count) {
        /* VideoInit has already recorded the first revision, including a
           legitimate zero value on an otherwise empty pasteboard. */
        SDL_SendClipboardUpdate();
        data->clipboard_count = count;
    }
}

/* OPENSTEP's NSRunAlertPanel draws and dispatches actions under GCD, but its
   runModalForWindow: loop fails to honor stopModalWithCode:.  A plain panel
   driven by the documented NSModalSession API has been verified on target. */
@interface SDL_OpenStepMessageBoxTarget : NSObject
{
    int selected;
}
- (id)init;
- (void)choose:(id)sender;
- (int)selected;
@end

@implementation SDL_OpenStepMessageBoxTarget
- (id)init
{
    self = [super init];
    if (self) selected = -1;
    return self;
}
- (void)choose:(id)sender
{
    selected = [sender tag];
}
- (int)selected
{
    return selected;
}
@end

static NSString *OPENSTEP_StringFromUTF8(const char *text)
{
    NSData *utf8;
    NSString *string;

    if (!text) text = "";
    utf8 = [[NSData alloc] initWithBytes:text length:(unsigned)SDL_strlen(text)];
    if (!utf8) return nil;
    string = [[NSString alloc] initWithData:utf8 encoding:NSUTF8StringEncoding];
    [utf8 release];
    return string;
}

/* Implement the complete SDL custom-button surface with an AppKit panel,
   rather than reducing it to NSRunAlertPanel's three fixed slots.  The panel
   is intentionally non-closable: SDL's result is a caller-supplied button
   ID, so an unselected close has no portable result to return. */
static int OPENSTEP_ShowMessageBoxInternal(const SDL_MessageBoxData *messageboxdata,
                                           int *buttonid)
{
    NSString *title;
    NSString *message;
    NSPanel *panel;
    NSTextField *label;
    SDL_OpenStepMessageBoxTarget *target;
    NSModalSession session;
    int selected;
    int i;
    int numbuttons;
    int displayed_buttons;
    int columns;
    int rows;
    int panel_height;

    if (!messageboxdata) return SDL_InvalidParamError("messageboxdata");
    numbuttons = messageboxdata->numbuttons;
    if (numbuttons < 0) {
        return SDL_SetError("Invalid number of buttons");
    }
    if (numbuttons > 0 && !messageboxdata->buttons) {
        return SDL_InvalidParamError("messageboxdata->buttons");
    }
    title = OPENSTEP_StringFromUTF8(messageboxdata->title);
    message = OPENSTEP_StringFromUTF8(messageboxdata->message);
    if (!title || !message) {
        [title release];
        [message release];
        return SDL_SetError("Message box text is not valid UTF-8");
    }
    /* SDL permits an empty custom-button array.  Keep its blocking dialog
       usable with a native implicit OK and report the conventional -1 ID. */
    displayed_buttons = numbuttons ? numbuttons : 1;
    columns = displayed_buttons < 3 ? displayed_buttons : 3;
    rows = (displayed_buttons + columns - 1) / columns;
    panel_height = 96 + rows * 38;
    panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 420, panel_height)
                                       styleMask:NSTitledWindowMask
                                         backing:NSBackingStoreBuffered
                                           defer:NO];
    target = [[SDL_OpenStepMessageBoxTarget alloc] init];
    label = [[NSTextField alloc] initWithFrame:NSMakeRect(18, panel_height - 74,
                                                            384, 48)];
    if (!panel || !target || !label) {
        [label release];
        [target release];
        [panel release];
        [title release];
        [message release];
        return SDL_OutOfMemory();
    }
    [panel setTitle:title];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setStringValue:message];
    [[panel contentView] addSubview:label];
    [label release];
    for (i = 0; i < displayed_buttons; ++i) {
        NSButton *button;
        const SDL_MessageBoxButtonData *button_data =
            (i < numbuttons) ? &messageboxdata->buttons[i] : NULL;
        NSString *button_text = button_data ?
            OPENSTEP_StringFromUTF8(button_data->text) : [@"OK" retain];
        int column = i % columns;
        int display_column = column;
        int row = i / columns;
        if (messageboxdata->flags & SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT) {
            display_column = columns - column - 1;
        }
        if (!button_text) {
            [title release];
            [message release];
            [target release];
            [panel release];
            return SDL_SetError("Message box button text is not valid UTF-8");
        }
        button = [[NSButton alloc] initWithFrame:NSMakeRect(18 + display_column * 132,
                                      18 + (rows - row - 1) * 38, 120, 28)];
        if (!button) {
            [button_text release];
            [title release];
            [message release];
            [target release];
            [panel release];
            return SDL_OutOfMemory();
        }
        [button setTitle:button_text];
        [button_text release];
        [button setTag:i];
        [button setTarget:target];
        [button setAction:@selector(choose:)];
        if (!button_data ||
            (button_data->flags & SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT)) {
            [panel setDefaultButtonCell:[button cell]];
        }
        if (!button_data ||
            (button_data->flags & SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT)) {
            [button setKeyEquivalent:@"\033"];
        }
        [[panel contentView] addSubview:button];
        [button release];
    }
    if (messageboxdata->window && messageboxdata->window->driverdata) {
        SDL_OpenStepWindowData *parent_data =
            (SDL_OpenStepWindowData *)messageboxdata->window->driverdata;
        if (parent_data->window) {
            NSRect parent_frame = [(NSWindow *)parent_data->window frame];
            NSRect panel_frame = [panel frame];
            [panel setFrameOrigin:NSMakePoint(
                parent_frame.origin.x + (parent_frame.size.width - panel_frame.size.width) / 2.0,
                parent_frame.origin.y + (parent_frame.size.height - panel_frame.size.height) / 2.0)];
        } else {
            [panel center];
        }
    } else {
        [panel center];
    }
    session = [NSApp beginModalSessionForWindow:panel];
    if (session == NULL) {
        [target release];
        [panel release];
        [title release];
        [message release];
        return SDL_SetError("OPENSTEP could not begin message box session");
    }
    while ([target selected] == -1) {
        [NSApp runModalSession:session];
    }
    selected = [target selected];
    [NSApp endModalSession:session];
    [panel orderOut:nil];
    if (buttonid) {
        *buttonid = numbuttons ? messageboxdata->buttons[selected].buttonid : -1;
    }
    [target release];
    [panel release];
    [title release];
    [message release];
    return 0;
}

static int OPENSTEP_ShowMessageBox(_THIS, const SDL_MessageBoxData *messageboxdata,
                                   int *buttonid)
{
    (void)_this;
    return OPENSTEP_ShowMessageBoxInternal(messageboxdata, buttonid);
}

static int OPENSTEP_ShowMessageBoxBootstrap(const SDL_MessageBoxData *messageboxdata,
                                            int *buttonid)
{
    [NSApplication sharedApplication];
    [NSApp finishLaunching];
    [NSApp activateIgnoringOtherApps:YES];
    return OPENSTEP_ShowMessageBoxInternal(messageboxdata, buttonid);
}

static SDL_Keymod OPENSTEP_Modifiers(NSEvent *event)
{
    unsigned int flags = [event modifierFlags];
    SDL_VideoDevice *device = SDL_GetVideoDevice();
    SDL_OpenStepVideoData *video_data = NULL;
    SDL_Keymod mod = KMOD_NONE;

    if (device != NULL) video_data = (SDL_OpenStepVideoData *)device->driverdata;
    /* OPENSTEP console input can report modifier state only in a preceding
       NSFlagsChanged event.  Preserve exactly that state per video device,
       as the completed SDL 1.2 port does, rather than guessing from the
       hardware-dependent keyCode. */
    if (flags != 0) {
        if (video_data != NULL) video_data->modifier_flags = flags;
    } else if (video_data != NULL) {
        flags = video_data->modifier_flags;
    }
    if (flags & NSShiftKeyMask) mod = (SDL_Keymod)(mod | KMOD_LSHIFT);
    if (flags & NSControlKeyMask) mod = (SDL_Keymod)(mod | KMOD_LCTRL);
    if (flags & NSAlternateKeyMask) mod = (SDL_Keymod)(mod | KMOD_LALT);
    if (flags & NSCommandKeyMask) mod = (SDL_Keymod)(mod | KMOD_LGUI);
    if (flags & NSAlphaShiftKeyMask) mod = (SDL_Keymod)(mod | KMOD_CAPS);
    /* AppKit attaches NSNumericPadKeyMask to keypad and cursor-key events;
       it is event classification rather than a NumLock state.  SDL KMOD_NUM
       represents the latter, so do not report it for ordinary arrow input. */
    /* NSFunctionKeyMask identifies AppKit function/navigation input.  It is
       not SDL's AltGr/Mode-switch modifier, so expose its key scancode
       without fabricating KMOD_MODE on F-keys or cursor keys. */
    return mod;
}

/* OPENSTEP's public NSEvent contract exposes aggregate modifier flags, not a
   portable left/right device-mask API.  Emit the standard left scancode for
   each aggregate transition so modifier-only input updates SDL's keyboard
   state, but do not invent separate right-side events when AppKit cannot
   distinguish them.  Caps Lock and Numeric Pad are state/toggle indicators,
   not reliable physical down/up pairs in this interface, and remain part of
   OPENSTEP_Modifiers only. */
static void OPENSTEP_SendModifierTransition(unsigned int before,
                                            unsigned int after,
                                            unsigned int mask,
                                            SDL_Scancode scancode)
{
    if ((before & mask) == (after & mask)) return;
    SDL_SendKeyboardKey((after & mask) ? SDL_PRESSED : SDL_RELEASED, scancode);
}

static void OPENSTEP_HandleModifierFlags(NSEvent *event)
{
    SDL_VideoDevice *device = SDL_GetVideoDevice();
    SDL_OpenStepVideoData *video_data = NULL;
    unsigned int before = 0;
    unsigned int after = [event modifierFlags];

    if (device != NULL) video_data = (SDL_OpenStepVideoData *)device->driverdata;
    if (video_data != NULL) {
        before = video_data->modifier_flags;
        video_data->modifier_flags = after;
    }
    OPENSTEP_SendModifierTransition(before, after, NSShiftKeyMask,
                                    SDL_SCANCODE_LSHIFT);
    OPENSTEP_SendModifierTransition(before, after, NSControlKeyMask,
                                    SDL_SCANCODE_LCTRL);
    OPENSTEP_SendModifierTransition(before, after, NSAlternateKeyMask,
                                    SDL_SCANCODE_LALT);
    OPENSTEP_SendModifierTransition(before, after, NSCommandKeyMask,
                                    SDL_SCANCODE_LGUI);
    SDL_SetModState(OPENSTEP_Modifiers(event));
}

static void OPENSTEP_SendMouseButton(SDL_Window *window, NSEvent *event,
                                     Uint8 state, Uint8 button)
{
    SDL_OpenStepWindowData *data;
    NSPoint point;

    if (!window || !window->driverdata) return;
    data = (SDL_OpenStepWindowData *)window->driverdata;
    if (!data->view) return;
    point = [(NSView *)data->view convertPoint:[event locationInWindow] fromView:nil];
    /* A button event delivered to this content view is authoritative mouse
       focus, independently of the order in which AppKit key-window
       notifications arrive. */
    SDL_SetMouseFocus(window);
    SDL_SendMouseMotion(window, 0, 0, (int)point.x, (int)point.y);
    SDL_SendMouseButton(window, 0, state, button);
}

static SDL_Scancode OPENSTEP_ScancodeForCharacter(unsigned short character)
{
    if (character >= 'a' && character <= 'z') return (SDL_Scancode)(SDL_SCANCODE_A + character - 'a');
    if (character >= 'A' && character <= 'Z') return (SDL_Scancode)(SDL_SCANCODE_A + character - 'A');
    if (character >= '1' && character <= '9') return (SDL_Scancode)(SDL_SCANCODE_1 + character - '1');
    if (character == '0') return SDL_SCANCODE_0;
    switch (character) {
    case 8: return SDL_SCANCODE_BACKSPACE; case 9: return SDL_SCANCODE_TAB;
    case 13: return SDL_SCANCODE_RETURN; case 27: return SDL_SCANCODE_ESCAPE;
    case 32: return SDL_SCANCODE_SPACE; case 127: return SDL_SCANCODE_DELETE;
    case '-': case '_': return SDL_SCANCODE_MINUS; case '=': case '+': return SDL_SCANCODE_EQUALS;
    case '[': case '{': return SDL_SCANCODE_LEFTBRACKET; case ']': case '}': return SDL_SCANCODE_RIGHTBRACKET;
    case '\\': case '|': return SDL_SCANCODE_BACKSLASH; case ';': case ':': return SDL_SCANCODE_SEMICOLON;
    case '\'': case '"': return SDL_SCANCODE_APOSTROPHE; case '`': case '~': return SDL_SCANCODE_GRAVE;
    case ',': case '<': return SDL_SCANCODE_COMMA; case '.': case '>': return SDL_SCANCODE_PERIOD;
    case '/': case '?': return SDL_SCANCODE_SLASH;
    case NSUpArrowFunctionKey: return SDL_SCANCODE_UP; case NSDownArrowFunctionKey: return SDL_SCANCODE_DOWN;
    case NSLeftArrowFunctionKey: return SDL_SCANCODE_LEFT; case NSRightArrowFunctionKey: return SDL_SCANCODE_RIGHT;
    case NSInsertFunctionKey: return SDL_SCANCODE_INSERT; case NSDeleteFunctionKey: return SDL_SCANCODE_DELETE;
    case NSHomeFunctionKey: return SDL_SCANCODE_HOME; case NSEndFunctionKey: return SDL_SCANCODE_END;
    case NSPageUpFunctionKey: return SDL_SCANCODE_PAGEUP; case NSPageDownFunctionKey: return SDL_SCANCODE_PAGEDOWN;
    case NSHelpFunctionKey: return SDL_SCANCODE_HELP;
    case NSPauseFunctionKey: return SDL_SCANCODE_PAUSE; case NSPrintFunctionKey: return SDL_SCANCODE_PRINTSCREEN;
    case NSClearDisplayFunctionKey: return SDL_SCANCODE_CLEAR;
    case NSF1FunctionKey: return SDL_SCANCODE_F1; case NSF2FunctionKey: return SDL_SCANCODE_F2;
    case NSF3FunctionKey: return SDL_SCANCODE_F3; case NSF4FunctionKey: return SDL_SCANCODE_F4;
    case NSF5FunctionKey: return SDL_SCANCODE_F5; case NSF6FunctionKey: return SDL_SCANCODE_F6;
    case NSF7FunctionKey: return SDL_SCANCODE_F7; case NSF8FunctionKey: return SDL_SCANCODE_F8;
    case NSF9FunctionKey: return SDL_SCANCODE_F9; case NSF10FunctionKey: return SDL_SCANCODE_F10;
    case NSF11FunctionKey: return SDL_SCANCODE_F11; case NSF12FunctionKey: return SDL_SCANCODE_F12;
    case NSF13FunctionKey: return SDL_SCANCODE_F13; case NSF14FunctionKey: return SDL_SCANCODE_F14;
    case NSF15FunctionKey: return SDL_SCANCODE_F15;
    default: return SDL_SCANCODE_UNKNOWN;
    }
}

/* AppKit represents navigation, editing and F1–F15 keys as private-use
   function characters.  They identify a physical SDL key but are not text
   input; forwarding their UTF-8 form creates bogus SDL_TEXTINPUT payloads. */
static SDL_bool OPENSTEP_IsFunctionCharacter(unsigned short character)
{
    return (character >= NSUpArrowFunctionKey &&
            character <= NSF15FunctionKey) ? SDL_TRUE : SDL_FALSE;
}

/* SDL_SendKeyboardText accepts UTF-8 and performs the SDL2-required split at
   text-event boundaries itself.  NSEvent's NSString can contain more than one
   UTF-16 code unit (composed input is the important case), so never reduce it
   to characterAtIndex:0 before converting it. */
static void OPENSTEP_SendKeyboardText(NSString *characters)
{
    NSData *utf8;
    unsigned int length;
    char *text;

    if (characters == nil || [characters length] == 0) return;
    utf8 = [characters dataUsingEncoding:NSUTF8StringEncoding];
    if (utf8 == nil) return;
    length = (unsigned int)[utf8 length];
    if (length == 0 || length == (unsigned int)-1) return;
    text = (char *)SDL_malloc((size_t)length + 1);
    if (text == NULL) {
        SDL_OutOfMemory();
        return;
    }
    SDL_memcpy(text, [utf8 bytes], length);
    text[length] = '\0';
    SDL_SendKeyboardText(text);
    SDL_free(text);
}

static void OPENSTEP_SendKey(NSEvent *event, Uint8 state)
{
    NSString *characters = [event characters];
    NSString *unmodified = [event charactersIgnoringModifiers];
    unsigned short character;
    SDL_Scancode scancode;

    SDL_SetModState(OPENSTEP_Modifiers(event));
    if ([characters length] == 0) return;
    /* SDL scancodes describe physical keys, whereas text describes the
       modifier/layout-resolved input.  AppKit documents the unmodified
       string precisely for this distinction.  If an input method supplies
       no unmodified character, retain the established character fallback. */
    if (unmodified != nil && [unmodified length] != 0) {
        character = (unsigned short)[unmodified characterAtIndex:0];
    } else {
        character = (unsigned short)[characters characterAtIndex:0];
    }
    scancode = OPENSTEP_ScancodeForCharacter(character);
    if (scancode != SDL_SCANCODE_UNKNOWN) SDL_SendKeyboardKey(state, scancode);
    if (state == SDL_PRESSED && !OPENSTEP_IsFunctionCharacter(character)) {
        OPENSTEP_SendKeyboardText(characters);
    }
}

static SDL_bool OPENSTEP_DropEventsEnabled(void)
{
    return (SDL_GetEventState(SDL_DROPFILE) == SDL_ENABLE ||
            SDL_GetEventState(SDL_DROPTEXT) == SDL_ENABLE) ? SDL_TRUE : SDL_FALSE;
}

@interface SDL_OpenStepView : NSView
{
    NSBitmapImageRep *_bitmap;
    SDL_Window *_sdl_window;
    NSTrackingRectTag _mouse_tracking_tag;
}
- initWithFrame:(NSRect)frame window:(SDL_Window *)window bitmap:(NSBitmapImageRep *)bitmap;
- (void)setSDLBitmap:(NSBitmapImageRep *)bitmap;
- (void)installMouseTrackingRect;
- (void)removeMouseTrackingRect;
@end

@implementation SDL_OpenStepView
- initWithFrame:(NSRect)frame window:(SDL_Window *)window bitmap:(NSBitmapImageRep *)bitmap
{
    self = [super initWithFrame:frame];
    _bitmap = [bitmap retain];
    _sdl_window = window;
    return self;
}
- (void)dealloc
{
    [self removeMouseTrackingRect];
    [_bitmap release];
    [super dealloc];
}
- (BOOL)isFlipped
{
    return YES;
}
- (void)setSDLBitmap:(NSBitmapImageRep *)bitmap
{
    if (_bitmap != bitmap) {
        [_bitmap release];
        _bitmap = [bitmap retain];
    }
}
- (void)removeMouseTrackingRect
{
    if (_mouse_tracking_tag != 0) {
        [self removeTrackingRect:_mouse_tracking_tag];
        _mouse_tracking_tag = 0;
    }
}
- (void)installMouseTrackingRect
{
    /* OPENSTEP keeps tracking rectangles at the NSWindow level, and its
       documentation requires removing/recreating them after a view frame or
       native-window change.  The full content bounds model SDL mouse focus. */
    [self removeMouseTrackingRect];
    _mouse_tracking_tag = [self addTrackingRect:[self bounds] owner:self
                                        userData:NULL assumeInside:NO];
}
- (void)drawRect:(NSRect)rect
{
    SDL_OpenStepWindowData *data = (_sdl_window && _sdl_window->driverdata)
        ? (SDL_OpenStepWindowData *)_sdl_window->driverdata : NULL;

    /*
     * NOT WHILE A STAMP OWNS THIS RECTANGLE.
     *
     * When the GL frame goes to the screen directly from video memory, this
     * bitmap stops being updated -- so drawing it here would paint a stale
     * picture, or on the very first expose an empty one, straight over the
     * live frame.  The next swap stamps again and the window comes back,
     * which makes it a flicker rather than a wrong picture, and that is
     * still the loudest thing this backend can do wrong.
     *
     * `presenting` is NOT this flag and must not be reused for it: it means
     * "SDL is mid-present, do not send an expose event", which is a
     * different question with a different answer.
     */
    if (_bitmap != nil && !(data && data->gl_stamping)) {
        [_bitmap drawInRect:[self bounds]];
    }
    if (data && !data->presenting) {
        SDL_SendWindowEvent(_sdl_window, SDL_WINDOWEVENT_EXPOSED, 0, 0);
    }
}
- (void)resetCursorRects
{
    SDL_OpenStepWindowData *data;
    NSCursor *cursor;

    [super resetCursorRects];
    cursor = [NSCursor arrowCursor];
    if (_sdl_window && _sdl_window->driverdata) {
        data = (SDL_OpenStepWindowData *)_sdl_window->driverdata;
        if (data->cursor != NULL) cursor = (NSCursor *)data->cursor;
    }
    if (cursor != nil) [self addCursorRect:[self bounds] cursor:cursor];
}
- (BOOL)acceptsFirstResponder
{
    return YES;
}
- (void)mouseDown:(NSEvent *)event
{
    OPENSTEP_SendMouseButton(_sdl_window, event, SDL_PRESSED, SDL_BUTTON_LEFT);
}
- (void)keyDown:(NSEvent *)event
{
    OPENSTEP_SendKey(event, SDL_PRESSED);
}
- (void)keyUp:(NSEvent *)event
{
    OPENSTEP_SendKey(event, SDL_RELEASED);
}
- (void)flagsChanged:(NSEvent *)event
{
    OPENSTEP_HandleModifierFlags(event);
}
- (void)mouseUp:(NSEvent *)event
{
    OPENSTEP_SendMouseButton(_sdl_window, event, SDL_RELEASED, SDL_BUTTON_LEFT);
}
- (void)rightMouseDown:(NSEvent *)event
{
    OPENSTEP_SendMouseButton(_sdl_window, event, SDL_PRESSED, SDL_BUTTON_RIGHT);
}
- (void)rightMouseUp:(NSEvent *)event
{
    OPENSTEP_SendMouseButton(_sdl_window, event, SDL_RELEASED, SDL_BUTTON_RIGHT);
}
- (void)mouseMoved:(NSEvent *)event
{
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    if (_sdl_window && _sdl_window->driverdata) {
        SDL_SetMouseFocus(_sdl_window);
    }
    SDL_SendMouseMotion(_sdl_window, 0, 0, (int)point.x, (int)point.y);
}
- (void)mouseEntered:(NSEvent *)event
{
    NSPoint point;

    if (!_sdl_window || !_sdl_window->driverdata) return;
    point = [self convertPoint:[event locationInWindow] fromView:nil];
    SDL_SetMouseFocus(_sdl_window);
    SDL_SendMouseMotion(_sdl_window, 0, 0, (int)point.x, (int)point.y);
}
- (void)mouseExited:(NSEvent *)event
{
    (void)event;
    if (SDL_GetMouseFocus() == _sdl_window) {
        SDL_SetMouseFocus(NULL);
    }
}
- (void)mouseDragged:(NSEvent *)event
{
    [self mouseMoved:event];
}
- (void)rightMouseDragged:(NSEvent *)event
{
    [self mouseMoved:event];
}
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
    (void)sender;
    if (_sdl_window && _sdl_window->driverdata && OPENSTEP_DropEventsEnabled()) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}
- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    (void)sender;
    return (_sdl_window && _sdl_window->driverdata && OPENSTEP_DropEventsEnabled()) ? YES : NO;
}
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard;
    NSArray *files;
    NSString *type;
    NSString *string;
    unsigned int i;
    SDL_bool delivered = SDL_FALSE;

    if (!_sdl_window || !_sdl_window->driverdata || !OPENSTEP_DropEventsEnabled()) {
        return NO;
    }

    pasteboard = [sender draggingPasteboard];

    /* This is the native file-list representation used by OPENSTEP 4.2.
       Convert each path explicitly: NSString does not promise a C UTF-8
       terminator and SDL_SendDropFile copies, rather than owns, its input. */
    if (SDL_GetEventState(SDL_DROPFILE) == SDL_ENABLE) {
        files = [pasteboard propertyListForType:NSFilenamesPboardType];
        for (i = 0; files != nil && i < [files count]; ++i) {
            id item = [files objectAtIndex:i];
            NSString *filename;
            NSData *utf8;
            char *path;
            unsigned int length;

            /* NSFilenamesPboardType normally guarantees NSString elements,
               but a malformed foreign pasteboard must not turn a drag into
               an Objective-C unrecognized-selector exception. */
            if (![item isKindOfClass:[NSString class]]) {
                continue;
            }
            filename = (NSString *)item;
            utf8 = [filename dataUsingEncoding:NSUTF8StringEncoding];
            if (utf8 == nil) {
                continue;
            }
            length = (unsigned int)[utf8 length];
            if (length == (unsigned int)-1) {
                continue;
            }
            path = (char *)SDL_malloc(length + 1);
            if (path == NULL) {
                continue;
            }
            SDL_memcpy(path, [utf8 bytes], length);
            path[length] = '\0';
            SDL_SendDropFile(_sdl_window, path);
            SDL_free(path);
            delivered = SDL_TRUE;
        }
    }

    /* A text-only drop is distinct from a file-list drop in SDL.  OPENSTEP
       exposes it as NSStringPboardType; copy it to explicit UTF-8 because
       SDL_SendDropText also copies, rather than owns, the input string. */
    if (SDL_GetEventState(SDL_DROPTEXT) == SDL_ENABLE) {
        /* NSPasteboard on OPENSTEP 4.2 raises an exception if stringForType:
           is sent for a representation not supplied by this drag source.
           An ordinary file-only drag can arrive while SDL_DROPTEXT is also
           enabled, so probe the offered types before requesting text. */
        type = [pasteboard availableTypeFromArray:
                          [NSArray arrayWithObject:NSStringPboardType]];
        string = (type != nil) ? [pasteboard stringForType:type] : nil;
        if (string != nil) {
            NSData *utf8 = [string dataUsingEncoding:NSUTF8StringEncoding];
            char *text;
            unsigned int length;

            if (utf8 != nil) {
                length = (unsigned int)[utf8 length];
                if (length != (unsigned int)-1) {
                    text = (char *)SDL_malloc(length + 1);
                    if (text != NULL) {
                        SDL_memcpy(text, [utf8 bytes], length);
                        text[length] = '\0';
                        SDL_SendDropText(_sdl_window, text);
                        SDL_free(text);
                        delivered = SDL_TRUE;
                    }
                }
            }
        }
    }
    if (delivered) {
        /* SDL's helper emits SDL_DROPBEGIN as needed and closes the sequence. */
        SDL_SendDropComplete(_sdl_window);
    }
    return delivered ? YES : NO;
}
- (void)windowDidBecomeKey:(NSNotification *)notification
{
    SDL_OpenStepWindowData *data;
    NSPoint point;
    NSRect bounds;

    (void)notification;
    SDL_SetKeyboardFocus(_sdl_window);
    SDL_SetMouseFocus(_sdl_window);
    if (!_sdl_window || !_sdl_window->driverdata) {
        return;
    }
    data = (SDL_OpenStepWindowData *)_sdl_window->driverdata;
    if (!data->window || !data->view) {
        return;
    }
    /* Refresh the ordinary SDL mouse state when AppKit gives this SDL
       window key focus.  No event need be queued at that instant, so use
       the documented AppKit out-of-stream base-coordinate query rather than
       keeping a stale coordinate from whichever native window was last key. */
    point = [(NSWindow *)data->window mouseLocationOutsideOfEventStream];
    point = [(NSView *)data->view convertPoint:point fromView:nil];
    bounds = [(NSView *)data->view bounds];
    if (point.x >= bounds.origin.x && point.x < bounds.origin.x + bounds.size.width &&
        point.y >= bounds.origin.y && point.y < bounds.origin.y + bounds.size.height) {
        SDL_SendMouseMotion(_sdl_window, 0, 0, (int)point.x, (int)point.y);
    }
}
- (void)windowDidResignKey:(NSNotification *)notification
{
    (void)notification;
    /* Do not erase focus newly assigned by another native SDL window if its
       become-key notification was delivered before this older resign-key
       notification.  This follows the standard SDL Cocoa backend ordering. */
    if (SDL_GetKeyboardFocus() == _sdl_window) {
        SDL_SetKeyboardFocus(NULL);
    }
    if (SDL_GetMouseFocus() == _sdl_window) {
        SDL_SetMouseFocus(NULL);
    }
}
- (BOOL)windowShouldClose:(id)sender
{
    /* A close-button action is a request, not destruction of an SDL window.
       SDL applications decide whether to destroy the window after receiving
       SDL_WINDOWEVENT_CLOSE. AppKit documents that returning NO from this
       delegate hook leaves the native window open. Backend teardown clears
       the delegate before it calls -close, so SDL_DestroyWindow still owns
       the one actual native close. */
    (void)sender;
    if (_sdl_window && _sdl_window->driverdata) {
        SDL_SendWindowEvent(_sdl_window, SDL_WINDOWEVENT_CLOSE, 0, 0);
    }
    return NO;
}
- (void)windowWillClose:(NSNotification *)notification
{
    if (_sdl_window && _sdl_window->driverdata) {
        SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)_sdl_window->driverdata;
        data->window = NULL;
        data->view = NULL;
        SDL_SendWindowEvent(_sdl_window, SDL_WINDOWEVENT_CLOSE, 0, 0);
    }
}
- (void)windowDidResize:(NSNotification *)notification
{
    NSRect frame = [self frame];
    (void)notification;
    [self installMouseTrackingRect];
    if (_sdl_window) {
        SDL_SendWindowEvent(_sdl_window, SDL_WINDOWEVENT_RESIZED,
                            (int)frame.size.width, (int)frame.size.height);
    }
}
- (void)windowDidMove:(NSNotification *)notification
{
    if (_sdl_window && _sdl_window->driverdata) {
        SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)_sdl_window->driverdata;
        NSWindow *native_window = (NSWindow *)data->window;
        NSScreen *screen = [NSScreen mainScreen];
        NSRect frame;
        NSRect content;
        NSRect screen_frame;
        if (native_window && screen) {
            frame = [native_window frame];
            content = [NSWindow contentRectForFrameRect:frame styleMask:[native_window styleMask]];
            screen_frame = [screen frame];
            SDL_SendWindowEvent(_sdl_window, SDL_WINDOWEVENT_MOVED,
                                (int)content.origin.x,
                                (int)(screen_frame.origin.y + screen_frame.size.height -
                                      content.origin.y - content.size.height));
        }
    }
}
- (void)windowDidMiniaturize:(NSNotification *)notification
{
    if (_sdl_window) {
        SDL_SendWindowEvent(_sdl_window, SDL_WINDOWEVENT_MINIMIZED, 0, 0);
    }
}
- (void)windowDidDeminiaturize:(NSNotification *)notification
{
    if (_sdl_window) {
        SDL_SendWindowEvent(_sdl_window, SDL_WINDOWEVENT_RESTORED, 0, 0);
    }
}
@end

/* SDL core calls this once after creating a window and whenever the app
   toggles SDL_DROPFILE or SDL_DROPTEXT event support. Register the actual content view:
   OPENSTEP delivers NSDraggingDestination methods to that view, as used by
   the target-validated openstep-mp3player. */
static void OPENSTEP_AcceptDragAndDrop(SDL_Window *window, SDL_bool accept)
{
    SDL_OpenStepWindowData *data;
    NSArray *types;

    if (!window || !window->driverdata) {
        return;
    }
    data = (SDL_OpenStepWindowData *)window->driverdata;
    if (!data->view) {
        return;
    }
    if (accept && SDL_GetEventState(SDL_DROPFILE) == SDL_ENABLE &&
        SDL_GetEventState(SDL_DROPTEXT) == SDL_ENABLE) {
        types = [NSArray arrayWithObjects:NSFilenamesPboardType,
                                      NSStringPboardType, nil];
        [(NSView *)data->view registerForDraggedTypes:types];
    } else if (accept && SDL_GetEventState(SDL_DROPFILE) == SDL_ENABLE) {
        types = [NSArray arrayWithObject:NSFilenamesPboardType];
        [(NSView *)data->view registerForDraggedTypes:types];
    } else if (accept && SDL_GetEventState(SDL_DROPTEXT) == SDL_ENABLE) {
        types = [NSArray arrayWithObject:NSStringPboardType];
        [(NSView *)data->view registerForDraggedTypes:types];
    } else {
        [(NSView *)data->view unregisterDraggedTypes];
    }
}

static SDL_VideoDevice *OPENSTEP_CreateDevice(void)
{
    SDL_VideoDevice *device;
    SDL_OpenStepVideoData *data;

    device = (SDL_VideoDevice *)SDL_calloc(1, sizeof(*device));
    data = (SDL_OpenStepVideoData *)SDL_calloc(1, sizeof(*data));
    if (!device || !data) {
        SDL_free(data);
        SDL_free(device);
        SDL_OutOfMemory();
        return NULL;
    }

    device->VideoInit = OPENSTEP_VideoInit;
    device->VideoQuit = OPENSTEP_VideoQuit;
    device->GetDisplayModes = OPENSTEP_GetDisplayModes;
    device->CreateSDLWindow = OPENSTEP_CreateSDLWindow;
    device->SetWindowTitle = OPENSTEP_SetWindowTitle;
    device->SetWindowIcon = OPENSTEP_SetWindowIcon;
    device->SetWindowPosition = OPENSTEP_SetWindowPosition;
    device->SetWindowSize = OPENSTEP_SetWindowSize;
    device->SetWindowMinimumSize = OPENSTEP_SetWindowMinimumSize;
    device->SetWindowMaximumSize = OPENSTEP_SetWindowMaximumSize;
    device->GetWindowBordersSize = OPENSTEP_GetWindowBordersSize;
    device->SetWindowInputFocus = OPENSTEP_SetWindowInputFocus;
    device->ShowWindow = OPENSTEP_ShowWindow;
    device->HideWindow = OPENSTEP_HideWindow;
    device->RaiseWindow = OPENSTEP_RaiseWindow;
    device->MaximizeWindow = OPENSTEP_MaximizeWindow;
    device->MinimizeWindow = OPENSTEP_MinimizeWindow;
    device->RestoreWindow = OPENSTEP_RestoreWindow;
    device->SetWindowBordered = OPENSTEP_SetWindowBordered;
    device->SetWindowResizable = OPENSTEP_SetWindowResizable;
    device->SetWindowAlwaysOnTop = OPENSTEP_SetWindowAlwaysOnTop;
    device->SetWindowFullscreen = OPENSTEP_SetWindowFullscreen;
    device->DestroyWindow = OPENSTEP_DestroyWindow;
    device->CreateWindowFramebuffer = OPENSTEP_CreateWindowFramebuffer;
    device->UpdateWindowFramebuffer = OPENSTEP_UpdateWindowFramebuffer;
    device->DestroyWindowFramebuffer = OPENSTEP_DestroyWindowFramebuffer;
    device->PumpEvents = OPENSTEP_PumpEvents;
    device->SetClipboardText = OPENSTEP_SetClipboardText;
    device->GetClipboardText = OPENSTEP_GetClipboardText;
    device->HasClipboardText = OPENSTEP_HasClipboardText;
    device->AcceptDragAndDrop = OPENSTEP_AcceptDragAndDrop;
    device->ShowMessageBox = OPENSTEP_ShowMessageBox;
    device->GL_LoadLibrary = OPENSTEP_GL_LoadLibrary;
    device->GL_GetProcAddress = OPENSTEP_GL_GetProcAddress;
    device->GL_UnloadLibrary = OPENSTEP_GL_UnloadLibrary;
    device->GL_CreateContext = OPENSTEP_GL_CreateContext;
    device->GL_MakeCurrent = OPENSTEP_GL_MakeCurrent;
    device->GL_GetDrawableSize = OPENSTEP_GL_GetDrawableSize;
    device->GL_SetSwapInterval = OPENSTEP_GL_SetSwapInterval;
    device->GL_GetSwapInterval = OPENSTEP_GL_GetSwapInterval;
    device->GL_SwapWindow = OPENSTEP_GL_SwapWindow;
    device->GL_DeleteContext = OPENSTEP_GL_DeleteContext;
    device->GL_DefaultProfileConfig = OPENSTEP_GL_DefaultProfileConfig;
    device->free = OPENSTEP_DeleteDevice;
    device->driverdata = data;
    /* OPENSTEP 4.2 has no display-mode switching API.  SDL still supports
       fullscreen windows at the desktop mode through SetWindowFullscreen. */
    device->quirk_flags |= VIDEO_DEVICE_QUIRK_DISABLE_DISPLAY_MODE_SWITCHING;
    return device;
}

VideoBootStrap OPENSTEP_bootstrap = {
    OPENSTEPVID_DRIVER_NAME, "OPENSTEP AppKit video driver",
    OPENSTEP_CreateDevice,
    OPENSTEP_ShowMessageBoxBootstrap
};

/* OPENSTEP 4.2 has no public display-mode switching interface.  Still expose
   the one mode we can truthfully describe, rather than making the SDL mode
   enumeration empty. SDL's video core owns and frees this copied record. */
static void OPENSTEP_GetDisplayModes(_THIS, SDL_VideoDisplay *display)
{
    SDL_DisplayMode mode;

    (void)_this;
    if (!display) {
        return;
    }
    mode = display->desktop_mode;
    if (mode.w > 0 && mode.h > 0) {
        SDL_AddDisplayMode(display, &mode);
    }
}

static int OPENSTEP_VideoInit(_THIS)
{
    SDL_OpenStepVideoData *data = (SDL_OpenStepVideoData *)_this->driverdata;
    SDL_DisplayMode mode;
    SDL_VideoDisplay display;
    SDL_Mouse *mouse;
    SDL_Cursor *default_cursor;
    NSScreen *screen;
    NSRect frame;

    data->autorelease_pool = (void *)[[NSAutoreleasePool alloc] init];
    data->application = (void *)[NSApplication sharedApplication];
    /* SDL creates NSApplication programmatically instead of through
       NSApplicationMain.  Complete the public launch lifecycle before the
       backend's AppKit event pump and NSModalSession message boxes run. */
    [(NSApplication *)data->application finishLaunching];
    [(NSApplication *)data->application activateIgnoringOtherApps:YES];
    data->clipboard_count = [[NSPasteboard generalPasteboard] changeCount];
    screen = [NSScreen mainScreen];
    if (screen == nil) {
        return SDL_SetError("OPENSTEP AppKit has no available screen");
    }
    frame = [screen frame];
    if ((frame.size.width <= 0.0) || (frame.size.height <= 0.0)) {
        return SDL_SetError("OPENSTEP AppKit reported an invalid screen size");
    }

    SDL_zero(mode);
    mode.format = SDL_PIXELFORMAT_RGB888;
    mode.w = (int)frame.size.width;
    mode.h = (int)frame.size.height;
    mode.refresh_rate = 0;
    SDL_zero(display);
    display.name = "OPENSTEP Main Display";
    display.desktop_mode = mode;
    display.current_mode = mode;
    if (SDL_AddVideoDisplay(&display, SDL_FALSE) < 0) return -1;

    mouse = SDL_GetMouse();
    mouse->CreateCursor = OPENSTEP_CreateCursor;
    mouse->CreateSystemCursor = OPENSTEP_CreateSystemCursor;
    mouse->ShowCursor = OPENSTEP_ShowCursor;
    mouse->FreeCursor = OPENSTEP_FreeCursor;
    mouse->WarpMouse = OPENSTEP_WarpMouse;
    mouse->GetGlobalMouseState = OPENSTEP_GetGlobalMouseState;
    default_cursor = OPENSTEP_CreateDefaultCursor();
    if (default_cursor) SDL_SetDefaultCursor(default_cursor);
    return 0;
}

static void OPENSTEP_VideoQuit(_THIS)
{
    SDL_OpenStepVideoData *data = (SDL_OpenStepVideoData *)_this->driverdata;

    if (data && data->invisible_cursor) {
        [(NSCursor *)data->invisible_cursor release];
        data->invisible_cursor = NULL;
    }
    if (data && data->autorelease_pool) {
        [(NSAutoreleasePool *)data->autorelease_pool release];
        data->autorelease_pool = NULL;
    }
    if (data) {
        data->application = NULL;
    }
}

static void OPENSTEP_DeleteDevice(_THIS)
{
    OPENSTEP_VideoQuit(_this);
    SDL_free(_this->driverdata);
    SDL_free(_this);
}

static int OPENSTEP_CreateSDLWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data;
    NSWindow *native_window;
    SDL_OpenStepView *view;
    NSScreen *screen;
    NSRect screen_frame;
    NSRect frame;
    NSRect restore_content;
    NSRect restore_frame;
    unsigned int style;
    unsigned int restore_style;

    data = (SDL_OpenStepWindowData *)SDL_calloc(1, sizeof(*data));
    if (!data) {
        return SDL_OutOfMemory();
    }

    screen = [NSScreen mainScreen];
    if (screen == nil) {
        SDL_free(data);
        return SDL_SetError("OPENSTEP AppKit has no available screen");
    }
    screen_frame = [screen frame];
    if (window->flags & SDL_WINDOW_FULLSCREEN) {
        /* SDL has already replaced window->x/y/w/h with the desktop bounds.
           Preserve the separate windowed geometry before AppKit can emit a
           resize notification for the initial fullscreen native window. */
        restore_style = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask;
        if (window->flags & SDL_WINDOW_RESIZABLE) {
            restore_style |= NSResizableWindowMask;
        }
        restore_content = NSMakeRect((float)window->windowed.x,
                                     screen_frame.origin.y + screen_frame.size.height -
                                     (float)window->windowed.y - (float)window->windowed.h,
                                     (float)window->windowed.w, (float)window->windowed.h);
        restore_frame = [NSWindow frameRectForContentRect:restore_content styleMask:restore_style];
        data->fullscreen_restore_x = restore_frame.origin.x;
        data->fullscreen_restore_y = restore_frame.origin.y;
        data->fullscreen_restore_w = restore_frame.size.width;
        data->fullscreen_restore_h = restore_frame.size.height;
        data->fullscreen_restore_content_w = (float)window->windowed.w;
        data->fullscreen_restore_content_h = (float)window->windowed.h;
        data->has_fullscreen_restore_frame = SDL_TRUE;
        frame = screen_frame;
    } else {
        frame = NSMakeRect((float)window->x,
                           screen_frame.origin.y + screen_frame.size.height -
                           (float)window->y - (float)window->h,
                           (float)window->w, (float)window->h);
    }
    style = OPENSTEP_WindowStyle(window);

    native_window = [[NSWindow alloc] initWithContentRect:frame
                                                 styleMask:style
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
    if (native_window == nil) {
        SDL_free(data);
        return SDL_SetError("OPENSTEP could not create an NSWindow");
    }
    view = [[SDL_OpenStepView alloc] initWithFrame:NSMakeRect(0.0, 0.0,
                                                               (float)window->w, (float)window->h)
                                           window:window bitmap:nil];
    if (view == nil) {
        [native_window release];
        SDL_free(data);
        return SDL_OutOfMemory();
    }

    data->window = (void *)native_window;
    data->view = (void *)view;
    data->sdl_window = window;
    data->width = window->w;
    data->height = window->h;
    window->driverdata = data;
    [native_window setContentView:view];
    [view installMouseTrackingRect];
    [native_window setDelegate:view];
    [native_window setAcceptsMouseMovedEvents:YES];
    [native_window makeFirstResponder:view];
    OPENSTEP_SetWindowTitle(_this, window);
    return 0;
}

static void OPENSTEP_SetWindowTitle(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSString *title;

    if (!data || !data->window) {
        return;
    }
    /* SDL titles are UTF-8.  NSString's legacy stringWithCString: uses the
       process default encoding and can silently corrupt a portable SDL title
       on OPENSTEP, so use the same explicit conversion as clipboard/message
       box text. */
    title = OPENSTEP_StringFromUTF8(window->title);
    if (title != nil) {
        [(NSWindow *)data->window setTitle:title];
        [title release];
    } else {
        SDL_SetError("OPENSTEP window title is not valid UTF-8");
    }
}

/* OPENSTEP exposes the dock/application icon through NSApplication rather
   than a per-NSWindow icon slot. SDL core has already converted `icon` to
   ARGB8888, but use SDL_GetRGBA instead of making an x86 byte-order
   assumption when filling AppKit's packed RGBA bitmap representation. */
static void OPENSTEP_SetWindowIcon(_THIS, SDL_Window *window, SDL_Surface *icon)
{
    NSBitmapImageRep *representation;
    NSImage *image;
    unsigned char *planes[5];
    int x;
    int y;

    (void)_this;
    (void)window;
    if (!icon || icon->w <= 0 || icon->h <= 0 || icon->w > 0x1fffffff ||
        icon->h > (0x7fffffff / (icon->w * 4))) {
        return;
    }
    representation = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:icon->w pixelsHigh:icon->h
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:icon->w * 4
        bitsPerPixel:32];
    if (representation == nil) {
        SDL_OutOfMemory();
        return;
    }
    [representation getBitmapDataPlanes:planes];
    for (y = 0; y < icon->h; ++y) {
        Uint32 *source = (Uint32 *)((Uint8 *)icon->pixels + y * icon->pitch);
        for (x = 0; x < icon->w; ++x) {
            Uint8 red;
            Uint8 green;
            Uint8 blue;
            Uint8 alpha;
            unsigned char *destination = planes[0] + ((y * icon->w + x) * 4);
            SDL_GetRGBA(source[x], icon->format, &red, &green, &blue, &alpha);
            destination[0] = red;
            destination[1] = green;
            destination[2] = blue;
            destination[3] = alpha;
        }
    }
    image = [[NSImage alloc] initWithSize:NSMakeSize((float)icon->w, (float)icon->h)];
    if (image == nil) {
        [representation release];
        SDL_OutOfMemory();
        return;
    }
    [image addRepresentation:representation];
    [representation release];
    [NSApp setApplicationIconImage:image];
    [image release];
}

static NSRect OPENSTEP_FrameForContent(SDL_Window *window, NSWindow *native_window,
                                       int x, int y, int w, int h)
{
    NSScreen *screen = [NSScreen mainScreen];
    NSRect screen_frame;
    NSRect content;

    (void)window;
    screen_frame = [screen frame];
    content = NSMakeRect((float)x,
                         screen_frame.origin.y + screen_frame.size.height - (float)y - (float)h,
                         (float)w, (float)h);
    return [NSWindow frameRectForContentRect:content styleMask:[native_window styleMask]];
}

static void OPENSTEP_SetWindowPosition(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;
    NSRect frame;

    (void)_this;
    if (!data || !data->window || [NSScreen mainScreen] == nil) return;
    native_window = (NSWindow *)data->window;
    frame = OPENSTEP_FrameForContent(window, native_window, window->x, window->y,
                                     window->w, window->h);
    [native_window setFrame:frame display:YES];
}

static void OPENSTEP_SetWindowSize(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;
    NSRect frame;

    (void)_this;
    /* The driver's surface is one size.  A resized window's rectangle no
     * longer describes it, so the lease ends here and the next swap decides
     * again against the new size. */
    OPENSTEP_GL_StampRelease(window);
    if (!data || !data->window || [NSScreen mainScreen] == nil) return;
    native_window = (NSWindow *)data->window;
    frame = OPENSTEP_FrameForContent(window, native_window, window->x, window->y,
                                     window->w, window->h);
    [native_window setFrame:frame display:YES];
    /* data->width/height describe the allocated AppKit presentation bitmap,
       not the requested native content size.  Leave them at the old bitmap
       dimensions so the next surface update or GL swap recreates it before
       copying the resized frame. */
}

static void OPENSTEP_SetWindowMinimumSize(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;
    NSRect frame;

    (void)_this;
    if (!data || !data->window) return;
    native_window = (NSWindow *)data->window;
    frame = [NSWindow frameRectForContentRect:NSMakeRect(0.0, 0.0,
                                                          (float)window->min_w,
                                                          (float)window->min_h)
                                styleMask:[native_window styleMask]];
    [native_window setMinSize:frame.size];
}

static void OPENSTEP_SetWindowMaximumSize(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;
    NSRect frame;

    (void)_this;
    if (!data || !data->window) return;
    native_window = (NSWindow *)data->window;
    frame = [NSWindow frameRectForContentRect:NSMakeRect(0.0, 0.0,
                                                          (float)window->max_w,
                                                          (float)window->max_h)
                                styleMask:[native_window styleMask]];
    [native_window setMaxSize:frame.size];
}

static int OPENSTEP_GetWindowBordersSize(_THIS, SDL_Window *window,
                                         int *top, int *left,
                                         int *bottom, int *right)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;
    NSRect frame;
    NSRect content;

    (void)_this;
    if (!data || !data->window) return SDL_SetError("OPENSTEP native window is unavailable");
    /* SDL_WINDOW_BORDERLESS is authoritative.  OPENSTEP's style-0 NSWindow
       can still report an implementation frame inset while hidden, but that
       inset is not an SDL-visible decoration and must not leak through the
       standard SDL_GetWindowBordersSize contract. */
    if (window->flags & SDL_WINDOW_BORDERLESS) {
        *top = *left = *bottom = *right = 0;
        return 0;
    }
    native_window = (NSWindow *)data->window;
    frame = [native_window frame];
    content = [NSWindow contentRectForFrameRect:frame styleMask:[native_window styleMask]];
    *top = (int)((frame.origin.y + frame.size.height) -
                 (content.origin.y + content.size.height));
    *left = (int)(content.origin.x - frame.origin.x);
    *bottom = (int)(content.origin.y - frame.origin.y);
    *right = (int)((frame.origin.x + frame.size.width) -
                   (content.origin.x + content.size.width));
    return 0;
}

static int OPENSTEP_SetWindowInputFocus(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;

    (void)_this;
    if (!data || !data->window || !data->view) {
        return SDL_SetError("OPENSTEP native window is unavailable");
    }
    native_window = (NSWindow *)data->window;
    [native_window makeKeyAndOrderFront:nil];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [native_window makeFirstResponder:(NSView *)data->view];
    return 0;
}

static void OPENSTEP_ShowWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;

    if (data && data->window) {
        [(NSWindow *)data->window makeKeyAndOrderFront:nil];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    }
}

static void OPENSTEP_HideWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;

    if (data && data->window) {
        [(NSWindow *)data->window orderOut:nil];
    }
}

static void OPENSTEP_RaiseWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;

    if (data && data->window) {
        [(NSWindow *)data->window orderFrontRegardless];
    }
}

static int OPENSTEP_RebuildNativeWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *old_window;
    NSWindow *new_window;
    NSView *view;
    NSRect old_frame;
    NSRect content;
    NSSize min_size;
    NSSize max_size;
    unsigned int style;
    int level;
    BOOL visible;

    (void)_this;
    if (!data || !data->window || !data->view) {
        return SDL_SetError("OPENSTEP cannot rebuild an unavailable native window");
    }
    old_window = (NSWindow *)data->window;
    view = (NSView *)data->view;
    old_frame = [old_window frame];
    content = [NSWindow contentRectForFrameRect:old_frame styleMask:[old_window styleMask]];
    min_size = [old_window minSize];
    max_size = [old_window maxSize];
    level = [old_window level];
    visible = [old_window isVisible];
    style = OPENSTEP_WindowStyle(window);
    new_window = [[NSWindow alloc] initWithContentRect:content
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    if (new_window == nil) {
        return SDL_SetError("OPENSTEP could not rebuild an NSWindow");
    }
    [view retain];
    [(SDL_OpenStepView *)view removeMouseTrackingRect];
    [old_window setDelegate:nil];
    [old_window setContentView:nil];
    [old_window close];
    [new_window setContentView:view];
    [view release];
    [(SDL_OpenStepView *)view installMouseTrackingRect];
    [new_window setDelegate:view];
    [new_window setAcceptsMouseMovedEvents:YES];
    [new_window makeFirstResponder:view];
    [new_window setMinSize:min_size];
    [new_window setMaxSize:max_size];
    [new_window setLevel:level];
    data->window = (void *)new_window;
    /* Keep native file-drop registration valid through a border/fullscreen
       rebuild. The destination is the retained view, but explicitly replay
       the current SDL event-state contract after moving it to the new owner. */
    OPENSTEP_AcceptDragAndDrop(window,
        OPENSTEP_DropEventsEnabled());
    /* A border/fullscreen transition creates a new NSWindow.  Reinstall the
       already selected SDL cursor rect on that native owner before it is
       ordered front, otherwise AppKit may fall back to its arrow cursor. */
    if (data->cursor != NULL) {
        [new_window invalidateCursorRectsForView:view];
    }
    OPENSTEP_SetWindowTitle(_this, window);
    if (visible) {
        [new_window makeKeyAndOrderFront:nil];
    }
    return 0;
}

static void OPENSTEP_SetWindowBordered(_THIS, SDL_Window *window,
                                       SDL_bool bordered)
{
    (void)bordered;
    (void)OPENSTEP_RebuildNativeWindow(_this, window);
}

static void OPENSTEP_SetWindowResizable(_THIS, SDL_Window *window,
                                        SDL_bool resizable)
{
    (void)resizable;
    (void)OPENSTEP_RebuildNativeWindow(_this, window);
}

static void OPENSTEP_MaximizeWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;
    NSScreen *screen;
    NSRect frame;

    (void)_this;
    if (!data || !data->window) return;
    native_window = (NSWindow *)data->window;
    screen = [NSScreen mainScreen];
    if (!screen) return;
    frame = [native_window frame];
    data->restore_x = frame.origin.x;
    data->restore_y = frame.origin.y;
    data->restore_w = frame.size.width;
    data->restore_h = frame.size.height;
    data->has_restore_frame = SDL_TRUE;
    [native_window setFrame:[screen frame] display:YES];
    SDL_SendWindowEvent(window, SDL_WINDOWEVENT_MAXIMIZED, 0, 0);
}

static void OPENSTEP_MinimizeWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;

    (void)_this;
    if (data && data->window) {
        [(NSWindow *)data->window miniaturize:nil];
    }
}

static void OPENSTEP_RestoreWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;
    NSRect frame;

    (void)_this;
    if (!data || !data->window) return;
    native_window = (NSWindow *)data->window;
    if ([native_window isMiniaturized]) {
        [native_window deminiaturize:nil];
    }
    if (data->has_restore_frame) {
        frame = NSMakeRect(data->restore_x, data->restore_y,
                           data->restore_w, data->restore_h);
        [native_window setFrame:frame display:YES];
        data->has_restore_frame = SDL_FALSE;
    }
    SDL_SendWindowEvent(window, SDL_WINDOWEVENT_RESTORED, 0, 0);
}

static void OPENSTEP_SetWindowAlwaysOnTop(_THIS, SDL_Window *window,
                                          SDL_bool on_top)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;

    (void)_this;
    if (data && data->window) {
        [(NSWindow *)data->window setLevel:(on_top ? NSFloatingWindowLevel : NSNormalWindowLevel)];
    }
}

static void OPENSTEP_SetWindowFullscreen(_THIS, SDL_Window *window,
                                         SDL_VideoDisplay *display, SDL_bool fullscreen)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;
    NSScreen *screen;
    NSRect frame;
    NSRect content;

    (void)display;
    if (!data || !data->window) {
        SDL_SetError("OPENSTEP native window is unavailable");
        return;
    }
    if (fullscreen) {
        native_window = (NSWindow *)data->window;
        frame = [native_window frame];
        data->fullscreen_restore_x = frame.origin.x;
        data->fullscreen_restore_y = frame.origin.y;
        data->fullscreen_restore_w = frame.size.width;
        data->fullscreen_restore_h = frame.size.height;
        content = [NSWindow contentRectForFrameRect:frame styleMask:[native_window styleMask]];
        data->fullscreen_restore_content_w = content.size.width;
        data->fullscreen_restore_content_h = content.size.height;
        data->has_fullscreen_restore_frame = SDL_TRUE;
        if (OPENSTEP_RebuildNativeWindow(_this, window) < 0) return;
        native_window = (NSWindow *)data->window;
        screen = [NSScreen mainScreen];
        if (!screen) {
            SDL_SetError("OPENSTEP AppKit has no available screen");
            return;
        }
        [native_window setFrame:[screen frame] display:YES];
        SDL_SendWindowEvent(window, SDL_WINDOWEVENT_RESIZED,
                            (int)[screen frame].size.width,
                            (int)[screen frame].size.height);
    } else {
        if (OPENSTEP_RebuildNativeWindow(_this, window) < 0) return;
        native_window = (NSWindow *)data->window;
        if (data->has_fullscreen_restore_frame) {
            [native_window setContentSize:NSMakeSize(data->fullscreen_restore_content_w,
                                                      data->fullscreen_restore_content_h)];
            [native_window setFrameOrigin:NSMakePoint(data->fullscreen_restore_x,
                                                       data->fullscreen_restore_y)];
            data->has_fullscreen_restore_frame = SDL_FALSE;
        } else {
            frame = OPENSTEP_FrameForContent(window, native_window,
                                              window->windowed.x, window->windowed.y,
                                              window->windowed.w, window->windowed.h);
            [native_window setFrame:frame display:YES];
        }
        SDL_SendWindowEvent(window, SDL_WINDOWEVENT_RESIZED,
                            window->windowed.w, window->windowed.h);
    }
}

static void OPENSTEP_DestroyWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSWindow *native_window;

    /* Before anything else: a lease outliving its window would leave the
     * driver in present mode with nobody to turn it off, and the next
     * window's first swap would deliver a stale array. */
    OPENSTEP_GL_StampRelease(window);
    if (!data) {
        return;
    }
    while (data->gl_contexts) {
        OPENSTEP_GL_DeleteContext(_this, (SDL_GLContext)data->gl_contexts);
    }
    OPENSTEP_DestroyWindowFramebuffer(_this, window);
    window->driverdata = NULL;
    native_window = (NSWindow *)data->window;
    if (data->view != NULL) {
        [(SDL_OpenStepView *)data->view removeMouseTrackingRect];
    }
    data->window = NULL;
    data->view = NULL;
    if (native_window != nil) {
        [native_window setDelegate:nil];
        [native_window close];
    }
    SDL_free(data);
}

static int OPENSTEP_CreateWindowFramebuffer(_THIS, SDL_Window *window,
                                             Uint32 *format, void **pixels,
                                             int *pitch)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    NSBitmapImageRep *bitmap;
    unsigned char *planes[5];
    size_t framebuffer_size;
    size_t present_size;

    if (!data || !data->view || window->w <= 0 || window->h <= 0) {
        return SDL_SetError("OPENSTEP cannot create a framebuffer for this window");
    }
    OPENSTEP_DestroyWindowFramebuffer(_this, window);
    data->framebuffer_pitch = window->w * 4;
    if (SDL_size_mul_overflow((size_t)data->framebuffer_pitch, (size_t)window->h, &framebuffer_size) < 0 ||
        SDL_size_mul_overflow((size_t)window->w * 3, (size_t)window->h, &present_size) < 0) {
        return SDL_OutOfMemory();
    }
    data->framebuffer_pixels = SDL_malloc(framebuffer_size);
    data->present_pixels = SDL_malloc(present_size);
    if (!data->framebuffer_pixels || !data->present_pixels) {
        OPENSTEP_DestroyWindowFramebuffer(_this, window);
        return SDL_OutOfMemory();
    }
    SDL_memset(data->framebuffer_pixels, 0, framebuffer_size);
    SDL_memset(data->present_pixels, 0, present_size);
    planes[0] = (unsigned char *)data->present_pixels;
    bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
                                                       pixelsWide:window->w
                                                       pixelsHigh:window->h
                                                    bitsPerSample:8
                                                  samplesPerPixel:3
                                                         hasAlpha:NO
                                                          isPlanar:NO
                                                colorSpaceName:NSCalibratedRGBColorSpace
                                                   bytesPerRow:window->w * 3
                                                  bitsPerPixel:24];
    if (bitmap == nil) {
        OPENSTEP_DestroyWindowFramebuffer(_this, window);
        return SDL_SetError("OPENSTEP could not create NSBitmapImageRep");
    }
    data->bitmap = (void *)bitmap;
    [(SDL_OpenStepView *)data->view setSDLBitmap:bitmap];
    [bitmap release];
    data->present_whole_once = SDL_TRUE;
    *format = SDL_PIXELFORMAT_RGB888;
    *pixels = data->framebuffer_pixels;
    *pitch = data->framebuffer_pitch;
    return 0;
}

/*
 * Move a 32-bit ARGB source into the window's 24-bit presentation bitmap.
 *
 * WHOSE ROW ZERO IS THE TOP is the caller's business, and it is an argument
 * rather than window state on purpose: a window's two sources disagree, and
 * a remembered flag goes stale across a swap, a context change or a resize.
 *
 *   SDL surfaces      top-down, so row y goes to h-1-y
 *   an OSMesa buffer  bottom-up (its yup default), so row y goes to row y
 *
 * The presentation bitmap is bottom-up either way; only where the rows are
 * read from changes.  The GL path used to ask OSMesa to write top-down
 * instead, with OSMesaPixelStore(OSMESA_Y_UP, 0), which flipped twice to the
 * same picture -- and cost the Matrox driver's accelerated surface, because
 * that path cannot reverse a row order and gives the surface back rather
 * than draw the wrong way up.
 */
static int OPENSTEP_PresentFramebuffer(_THIS, SDL_Window *window,
                                       const SDL_Rect *rects, int numrects,
                                       SDL_bool reverse_rows)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    SDL_Rect full_rect;
    int index;
    int u_left = 0, u_top = 0, u_right = 0, u_bottom = 0;
    SDL_bool have_union = SDL_FALSE;
    NSRect bounds, dirty;

    if (!data || !data->framebuffer_pixels || !data->present_pixels) {
        return SDL_SetError("OPENSTEP window framebuffer is not available");
    }
    if (!rects || numrects <= 0) {
        full_rect.x = 0;
        full_rect.y = 0;
        full_rect.w = window->w;
        full_rect.h = window->h;
        rects = &full_rect;
        numrects = 1;
    }
    for (index = 0; index < numrects; ++index) {
        int x, y, left, top, right, bottom;
        left = rects[index].x < 0 ? 0 : rects[index].x;
        top = rects[index].y < 0 ? 0 : rects[index].y;
        right = rects[index].x + rects[index].w;
        bottom = rects[index].y + rects[index].h;
        if (right > window->w) right = window->w;
        if (bottom > window->h) bottom = window->h;
        if (left >= right || top >= bottom) continue;
        if (!have_union) {
            u_left = left; u_top = top; u_right = right; u_bottom = bottom;
            have_union = SDL_TRUE;
        } else {
            if (left < u_left) u_left = left;
            if (top < u_top) u_top = top;
            if (right > u_right) u_right = right;
            if (bottom > u_bottom) u_bottom = bottom;
        }
        for (y = top; y < bottom; ++y) {
            Uint32 *source = (Uint32 *)((Uint8 *)data->framebuffer_pixels + y * data->framebuffer_pitch);
            int drow = reverse_rows ? (window->h - 1 - y) : y;
            Uint8 *target = (Uint8 *)data->present_pixels + (drow * window->w + left) * 3;
            for (x = left; x < right; ++x) {
                Uint32 pixel = source[x];
                *target++ = (Uint8)(pixel >> 16);
                *target++ = (Uint8)(pixel >> 8);
                *target++ = (Uint8)pixel;
            }
        }
    }
    /*
     * ONLY WHAT CHANGED GOES TO THE WINDOW SERVER.
     *
     * This used to display the whole bounds on every present, so a caller
     * that changed one 152-pixel cursor cell still had the Window Server
     * take the entire 640x480 24-bit picture.  Measured on the machine
     * (2026-09-29, a game sending ~9 small updates a second): 51 of 54
     * SNDStartPlaying stalls of 25-42 ms began 65-85 ms after such an
     * update, against a random baseline spread from 9 ms to 17 s -- the
     * audible result was a steady crackle.
     *
     * The view is flipped and the bitmap is drawn over [self bounds], so
     * while the bounds are exactly the window's size at the origin a
     * surface rectangle IS the view rectangle; AppKit clips drawRect: to
     * it.  In every other case -- a bounds/size mismatch in the middle of
     * a resize, or nothing left after clamping -- this does what it always
     * did and displays everything, so no rounding rule is ever needed.
     * So does the first present after the bitmap is (re)created: until
     * then the window shows whatever it held before, not the zeroed
     * bitmap, and a partial first update would leave that around it.
     * The GL path passes no rectangles and so still gets the full bounds.
     */
    bounds = [(NSView *)data->view bounds];
    dirty = bounds;
    if (have_union && !data->present_whole_once &&
        bounds.origin.x == 0.0 && bounds.origin.y == 0.0 &&
        bounds.size.width == (float)window->w &&
        bounds.size.height == (float)window->h) {
        dirty = NSMakeRect((float)u_left, (float)u_top,
                           (float)(u_right - u_left), (float)(u_bottom - u_top));
    }
    data->present_whole_once = SDL_FALSE;
    data->presenting = SDL_TRUE;
    [(SDL_OpenStepView *)data->view displayRect:dirty];
    data->presenting = SDL_FALSE;
    return 0;
}

/*
 * The SDL callback keeps its signature; SDL surfaces are top-down, so this
 * is the reversing form.
 */
static int OPENSTEP_UpdateWindowFramebuffer(_THIS, SDL_Window *window,
                                            const SDL_Rect *rects, int numrects)
{
    return OPENSTEP_PresentFramebuffer(_this, window, rects, numrects, SDL_TRUE);
}

static void OPENSTEP_DestroyWindowFramebuffer(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;

    if (!data) return;
    if (data->view) {
        [(SDL_OpenStepView *)data->view setSDLBitmap:nil];
    }
    data->bitmap = NULL;
    SDL_free(data->framebuffer_pixels);
    SDL_free(data->present_pixels);
    data->framebuffer_pixels = NULL;
    data->present_pixels = NULL;
    data->framebuffer_pitch = 0;
}

static void OPENSTEP_GL_RemoveContext(SDL_OpenStepGLContext *context)
{
    SDL_OpenStepGLContext **link;

    if (!context->window_data) return;
    link = (SDL_OpenStepGLContext **)&context->window_data->gl_contexts;
    while (*link) {
        if (*link == context) {
            *link = context->next;
            break;
        }
        link = &(*link)->next;
    }
    context->window_data = NULL;
    context->window = NULL;
    context->next = NULL;
}

static void OPENSTEP_GL_AddContext(SDL_OpenStepGLContext *context,
                                   SDL_Window *window,
                                   SDL_OpenStepWindowData *data)
{
    context->window = window;
    context->window_data = data;
    context->next = (SDL_OpenStepGLContext *)data->gl_contexts;
    data->gl_contexts = context;
}

static int OPENSTEP_GL_BindBuffer(SDL_OpenStepGLContext *context,
                                  SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    void *pixels;
    size_t pixels_size;

    if (!data || window->w <= 0 || window->h <= 0) {
        return SDL_SetError("OPENSTEP cannot bind OSMesa to this window");
    }
    if (SDL_size_mul_overflow((size_t)window->w, (size_t)window->h, &pixels_size) < 0 ||
        SDL_size_mul_overflow(pixels_size, (size_t)4, &pixels_size) < 0) {
        return SDL_OutOfMemory();
    }
    if (context->width != window->w || context->height != window->h ||
        context->pixels == NULL) {
        pixels = SDL_malloc(pixels_size);
        if (!pixels) return SDL_OutOfMemory();
        SDL_memset(pixels, 0, pixels_size);
        if (!OSMesaMakeCurrent(context->context, pixels, GL_UNSIGNED_BYTE,
                               window->w, window->h)) {
            SDL_free(pixels);
            return SDL_SetError("OPENSTEP OSMesa could not bind its RGBA buffer");
        }
        /*
         * BOTTOM-UP, said rather than assumed.
         *
         * This asked for 0 -- top-down -- and the present copy then reversed
         * it, so the picture was flipped twice.  It also ended the Matrox
         * driver's substitution on every bind: that path cannot reverse rows,
         * so Mesa's guard hands the video-memory surface back rather than
         * draw upside down.  Measured: the surface was claimed and released
         * inside SDL_CreateWindow, every time.
         *
         * Set explicitly and after every successful bind, because yup is
         * CONTEXT state rather than bind state -- Mesa's creation default
         * happens to be GL_TRUE, and relying on that would leave a later
         * rebind carrying whatever was there before.
         */
        OSMesaPixelStore(OSMESA_Y_UP, 1);
        SDL_free(context->pixels);
        context->pixels = pixels;
        context->pixels_size = pixels_size;
        context->width = window->w;
        context->height = window->h;
    } else {
        if (!OSMesaMakeCurrent(context->context, context->pixels,
                               GL_UNSIGNED_BYTE, context->width,
                               context->height)) {
            return SDL_SetError("OPENSTEP OSMesa could not make its context current");
        }
        /* The rebind path needs it too: yup is context state, and this
         * context may have been left with something else. */
        OSMesaPixelStore(OSMESA_Y_UP, 1);
    }
    if (context->window_data != data) {
        OPENSTEP_GL_RemoveContext(context);
        OPENSTEP_GL_AddContext(context, window, data);
    }
    return 0;
}

static int OPENSTEP_GL_EnsurePresentation(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    Uint32 format;
    void *pixels;
    int pitch;
    int result;

    if (!data) return SDL_SetError("OPENSTEP OpenGL window data is unavailable");
    if (data->present_pixels && data->width == window->w && data->height == window->h) {
        return 0;
    }
    OPENSTEP_DestroyWindowFramebuffer(_this, window);
    result = OPENSTEP_CreateWindowFramebuffer(_this, window, &format, &pixels, &pitch);
    if (result < 0) return result;
    SDL_free(data->framebuffer_pixels);
    data->framebuffer_pixels = NULL;
    data->framebuffer_pitch = 0;
    data->width = window->w;
    data->height = window->h;
    return 0;
}

/* OSMesaGetCurrentContext() returns Mesa's OSMesaContext, not SDL's
   SDL_OpenStepGLContext wrapper.  Resolve that opaque Mesa pointer through
   the window-owned wrapper list before accessing SDL fields. */
static SDL_OpenStepGLContext *OPENSTEP_GL_CurrentWindowContext(
    SDL_OpenStepWindowData *data, SDL_Window *window)
{
    OSMesaContext current = OSMesaGetCurrentContext();
    SDL_OpenStepGLContext *context;

    if (!data || !current) return NULL;
    for (context = (SDL_OpenStepGLContext *)data->gl_contexts;
         context != NULL; context = context->next) {
        if (context->window == window && context->context == current) {
            return context;
        }
    }
    return NULL;
}

static int OPENSTEP_GL_LoadLibrary(_THIS, const char *path)
{
    if (path != NULL) {
        return SDL_SetError("OPENSTEP uses its statically linked Mesa 3.4.2 OpenGL library");
    }
    SDL_strlcpy(_this->gl_config.driver_path, "Mesa 3.4.2 OSMesa (static)",
                SDL_arraysize(_this->gl_config.driver_path));
    return 0;
}

static void *OPENSTEP_GL_GetProcAddress(_THIS, const char *proc)
{
    (void)_this;
    if (!proc || !*proc) {
        SDL_InvalidParamError("proc");
        return NULL;
    }
    return (void *)_glapi_get_proc_address(proc);
}

static void OPENSTEP_GL_UnloadLibrary(_THIS)
{
    (void)_this;
    /* Mesa is linked statically into the final SDL2 archive/application. */
}

static void OPENSTEP_GL_DefaultProfileConfig(_THIS, int *mask,
                                              int *major, int *minor)
{
    (void)_this;
    *mask = 0;
    *major = 1;
    *minor = 2;
}

static SDL_GLContext OPENSTEP_GL_CreateContext(_THIS, SDL_Window *window)
{
    SDL_OpenStepGLContext *context;
    OSMesaContext share = NULL;

    if (_this->gl_config.profile_mask != 0 ||
        _this->gl_config.major_version < 1 ||
        _this->gl_config.major_version > 1 ||
        _this->gl_config.minor_version > 2) {
        SDL_SetError("OPENSTEP Mesa supports only compatibility OpenGL 1.0 through 1.2");
        return NULL;
    }
    if (_this->gl_config.red_size > 8 || _this->gl_config.green_size > 8 ||
        _this->gl_config.blue_size > 8 || _this->gl_config.alpha_size > 8 ||
        _this->gl_config.depth_size > 16 || _this->gl_config.stencil_size > 8 ||
        _this->gl_config.accum_red_size || _this->gl_config.accum_green_size ||
        _this->gl_config.accum_blue_size || _this->gl_config.accum_alpha_size ||
        _this->gl_config.stereo || _this->gl_config.multisamplebuffers ||
        _this->gl_config.multisamplesamples || _this->gl_config.floatbuffers ||
        _this->gl_config.framebuffer_srgb_capable || _this->gl_config.accelerated > 0) {
        SDL_SetError("OPENSTEP Mesa 3.4.2 OSMesa cannot provide the requested GL framebuffer");
        return NULL;
    }
    if (_this->gl_config.share_with_current_context) {
        share = OSMesaGetCurrentContext();
    }
    context = (SDL_OpenStepGLContext *)SDL_calloc(1, sizeof(*context));
    if (!context) return NULL;
    context->context = OSMesaCreateContext(OSMESA_ARGB, share);
    if (!context->context) {
        SDL_free(context);
        SDL_SetError("OPENSTEP OSMesaCreateContext failed");
        return NULL;
    }
    if (OPENSTEP_GL_BindBuffer(context, window) < 0) {
        OSMesaDestroyContext(context->context);
        SDL_free(context);
        return NULL;
    }
    return (SDL_GLContext)context;
}

static int OPENSTEP_GL_MakeCurrent(_THIS, SDL_Window *window,
                                   SDL_GLContext context)
{
    SDL_OpenStepGLContext *gl_context = (SDL_OpenStepGLContext *)context;

    (void)_this;
    /*
     * ANY change of what is current ends the lease.
     *
     * The driver's surface, its application array and its present flag are
     * one set for the whole process, so a lease is only ever meaningful
     * while the context that drew into that surface is the current one.
     * Pointing GL somewhere else -- another window, another context, or
     * nothing -- and leaving present mode on would have the next swap stamp
     * a surface that is no longer the one being drawn.
     */
    if (openstep_stamp_owner && openstep_stamp_owner != window)
        OPENSTEP_GL_StampReleaseOwner();
    if (!gl_context) {
        OPENSTEP_GL_StampReleaseOwner();
        gl_make_current(NULL, NULL);
        return 0;
    }
    if (!window) return SDL_SetError("OPENSTEP OSMesa requires an SDL window");
    return OPENSTEP_GL_BindBuffer(gl_context, window);
}

static void OPENSTEP_GL_GetDrawableSize(_THIS, SDL_Window *window, int *w, int *h)
{
    (void)_this;
    *w = window->w;
    *h = window->h;
}

static int OPENSTEP_GL_SetSwapInterval(_THIS, int interval)
{
    (void)_this;
    if (interval != 0) {
        return SDL_SetError("OPENSTEP OSMesa has no display-retrace swap interval");
    }
    return 0;
}

static int OPENSTEP_GL_GetSwapInterval(_THIS)
{
    (void)_this;
    return 0;
}


/*
 * The registered hooks, or NULL, having been checked rather than trusted.
 *
 * The ABI word alone would not be enough: a struct that grows leaves an
 * older registration SHORTER than this file believes, so every field is
 * confirmed to lie inside the size the registration declared before it is
 * read.  A short struct, a wrong ABI or a missing entry all mean "no
 * stamping", never a crash.
 */
static const SDL_OpenStepGLPresent *
OPENSTEP_GL_PresentHooks(SDL_Window *window)
{
    const SDL_OpenStepGLPresent *h;

    if (!window) return NULL;
    h = (const SDL_OpenStepGLPresent *)
            SDL_GetWindowData(window, SDL_OPENSTEP_GLPRESENT_KEY);
    if (!h) return NULL;
    if (h->abi != SDL_OPENSTEP_GLPRESENT_ABI) return NULL;
    if (h->size < sizeof(SDL_OpenStepGLPresent)) return NULL;
    if (!h->surface_origin || !h->set_present_mode || !h->present_rect)
        return NULL;
    return h;
}

/* Whoever holds it.  Used where the window that held it is not to hand, or
 * where any lease at all would be wrong -- a context going away, a context
 * being pointed at a different window. */
static void
OPENSTEP_GL_StampReleaseOwner(void)
{
    if (openstep_stamp_owner)
        OPENSTEP_GL_StampRelease(openstep_stamp_owner);
}

/* Give the screen rectangle back, and with it the driver's present mode --
 * which also leaves the caller's array refreshed, so the ordinary AppKit
 * path has a picture to draw the moment it takes over. */
static void
OPENSTEP_GL_StampRelease(SDL_Window *window)
{
    SDL_OpenStepWindowData *data;
    const SDL_OpenStepGLPresent *h;

    if (!window) return;
    data = (SDL_OpenStepWindowData *)window->driverdata;
    if (!data || !data->gl_stamping) return;
    h = (const SDL_OpenStepGLPresent *)data->gl_present;
    if (h) h->set_present_mode(0);
    data->gl_stamping = SDL_FALSE;
    data->gl_present = NULL;
    if (openstep_stamp_owner == window) openstep_stamp_owner = NULL;
}

/*
 * Put this window's frame on the screen without it crossing the bus.
 *
 * Returns SDL_TRUE if the screen now holds the frame.  SDL_FALSE means the
 * caller must deliver the ordinary way, and the ordinary way is always
 * correct -- every guard here stands the stamp down rather than risking a
 * rectangle that is not this window's.
 */
typedef struct {
    unsigned long srcX, srcY;
    long dstX, dstY;
    long w, h;
} OPENSTEP_StampRect;

static SDL_bool
OPENSTEP_GL_StampArm(_THIS, SDL_Window *window, OPENSTEP_StampRect *out)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    const SDL_OpenStepGLPresent *h;
    SDL_DisplayMode mode;
    Uint32 flags;
    int wx = 0, wy = 0;
    long dstX, dstY;
    long pw, ph;
    unsigned long srcX = 0UL, srcY = 0UL;

    if (!data || data->gl_stamp_barred) return SDL_FALSE;

    h = OPENSTEP_GL_PresentHooks(window);
    if (!h) { OPENSTEP_GL_StampRelease(window); return SDL_FALSE; }

    /* No surface in video memory means nothing to stamp -- this is where a
     * software Mesa, and an accelerated one that has fallen back, land. */
    if (h->surface_origin() == 0UL) {
        OPENSTEP_GL_StampRelease(window);
        return SDL_FALSE;
    }

    /* The lease.  A second window does not take it from the first. */
    if (openstep_stamp_owner && openstep_stamp_owner != window)
        return SDL_FALSE;

    flags = SDL_GetWindowFlags(window);
    /*
     * A STAMP IS NOT COMPOSITING.  The window server does not know these
     * pixels exist, so the rectangle lands on top of whatever overlaps it.
     * Focus is the only cheap proxy for "this window is the one in front",
     * and it is an imperfect one: a menu or a panel can cover the rectangle
     * without taking focus.  So this owns the screen only while it is
     * plainly the window in use, and hands back otherwise.
     */
    if ((flags & SDL_WINDOW_MINIMIZED) || !(flags & SDL_WINDOW_SHOWN) ||
        !(flags & SDL_WINDOW_INPUT_FOCUS)) {
        OPENSTEP_GL_StampRelease(window);
        return SDL_FALSE;
    }
    if (SDL_GetDesktopDisplayMode(0, &mode) != 0) return SDL_FALSE;

    SDL_GetWindowPosition(window, &wx, &wy);
    /*
     * MOVED SINCE LAST FRAME: stand down for one frame.  SDL's position is
     * a cache updated when a move event is dispatched, so during a drag it
     * lags the server -- and a stamp at a stale position lands on somebody
     * else's window.  Skipping while it changes is the answer available
     * here; it does not remove the lag, it declines to paint through it.
     */
    if (wx != data->gl_stamp_last_x || wy != data->gl_stamp_last_y) {
        data->gl_stamp_last_x = wx;
        data->gl_stamp_last_y = wy;
        return SDL_FALSE;
    }

    /* SDL's window position already counts from the top of the screen: the
     * backend converts to AppKit's bottom-left origin when it places the
     * window, so the scanout destination needs no flip of its own. */
    dstX = (long)wx;
    dstY = (long)wy;
    pw = (long)window->w;
    ph = (long)window->h;
    if (dstX < 0) { srcX = (unsigned long)(-dstX); pw += dstX; dstX = 0; }
    if (dstY < 0) { srcY = (unsigned long)(-dstY); ph += dstY; dstY = 0; }
    if (dstY + ph > (long)mode.h) ph = (long)mode.h - dstY;
    if (dstX + pw > (long)mode.w) pw = (long)mode.w - dstX;
    if (pw <= 0 || ph <= 0) return SDL_FALSE;

    if (!data->gl_stamping) {
        h->set_present_mode(1);
        data->gl_present = (void *)h;
        data->gl_stamping = SDL_TRUE;
        openstep_stamp_owner = window;
    }

    out->srcX = srcX; out->srcY = srcY;
    out->dstX = dstX; out->dstY = dstY;
    out->w = pw;      out->h = ph;
    return SDL_TRUE;
}

/*
 * ROW BY ROW, IN REVERSE, and it is the row order that forces it.
 *
 * The accelerated surface is written bottom-up -- Mesa's OSMESA_Y_UP, which
 * the driver requires of an accelerated context -- while the screen is
 * scanned top-down, so a single blit of the whole rectangle arrives upside
 * down.  The demo that proved this path could swap its own projection
 * instead; a LIBRARY cannot, because the projection belongs to the
 * application.
 *
 * So the flip happens here, a row at a time.  Measured at 800x600: 8.01 ms
 * against 3.69 for one blit -- one kernel entry costs 7.21 us -- which is
 * 43.72 frames a second against 54.60, and against 0.54 for the readback
 * this replaces.  Four fifths of the best possible, for no driver change.
 *
 * One blit becomes possible if the driver's present ever learns to walk its
 * source upward.  That is recorded as an option and NOT assumed: the sign
 * bit it would need is used in that driver for overlap ordering, where
 * source and destination both walk up and nothing is mirrored.
 *
 * Runs AFTER the flush, so the card has finished drawing what it stamps.
 */
static SDL_bool
OPENSTEP_GL_StampRun(SDL_Window *window, const OPENSTEP_StampRect *r)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    const SDL_OpenStepGLPresent *h = (const SDL_OpenStepGLPresent *)data->gl_present;
    unsigned long verdict = 0UL;
    long row;

    for (row = 0; row < r->h; row++) {
        if (h->present_rect(r->srcX, r->srcY + (unsigned long)row,
                            (unsigned long)r->w, 1UL,
                            r->dstX, r->dstY + (r->h - 1 - row),
                            &verdict) != 0) {
            /*
             * A refusal is a state change, not a log line, and which
             * refusal it was decides for how long.  Busy is this frame;
             * a destination that left the screen is until it comes back;
             * anything else the next frame cannot fix, so it bars this
             * window rather than failing once a frame forever.
             */
            if (verdict != 5UL /* E_BUSY */ && verdict != 3UL /* E_DST */)
                data->gl_stamp_barred = SDL_TRUE;
            return SDL_FALSE;
        }
    }
    return SDL_TRUE;
}

static int OPENSTEP_GL_SwapWindow(_THIS, SDL_Window *window)
{
    SDL_OpenStepWindowData *data = (SDL_OpenStepWindowData *)window->driverdata;
    SDL_OpenStepGLContext *context;
    void *saved_pixels;
    int saved_pitch;
    int result;
    OPENSTEP_StampRect rect;
    SDL_bool armed;

    context = OPENSTEP_GL_CurrentWindowContext(data, window);
    if (!context) {
        return SDL_SetError("OPENSTEP OSMesa context is not current for this window");
    }

    /*
     * THE PATH IS CHOSEN BEFORE glFinish, and the order is not cosmetic.
     *
     * Leaving the driver's present mode is what refreshes the caller's
     * array, and the refresh happens at the next flush.  Decide after the
     * flush and a window falling back would deliver whatever the array held
     * when the stamping began -- usually its first frame, sometimes nothing
     * -- with no error anywhere.
     */
    armed = OPENSTEP_GL_StampArm(_this, window, &rect);

    /*
     * And the flush comes between the two halves, doing two jobs at once:
     * it finishes the drawing the stamp is about to copy, and -- when
     * arming just left present mode -- it is the flush at which the driver
     * mirrors the surface back, so the AppKit path below has a picture.
     */
    glFinish();

    if (armed && OPENSTEP_GL_StampRun(window, &rect))
        return 0;

    /*
     * The stamp was refused after arming.  The caller's array is stale
     * because present mode was on, so hand the rectangle back and flush
     * once more to have the surface mirrored into it -- otherwise this
     * frame would deliver whatever the array held before the stamping
     * started.  Only ever costs anything on a refusal.
     */
    if (armed) {
        OPENSTEP_GL_StampRelease(window);
        glFinish();
    }

    if (OPENSTEP_GL_EnsurePresentation(_this, window) < 0) return -1;
    saved_pixels = data->framebuffer_pixels;
    saved_pitch = data->framebuffer_pitch;
    data->framebuffer_pixels = context->pixels;
    data->framebuffer_pitch = context->width * 4;
    /*
     * NOT reversed: OSMesa writes bottom-up now (see the bind below), which
     * is the direction the presentation bitmap already wants.
     */
    result = OPENSTEP_PresentFramebuffer(_this, window, NULL, 0, SDL_FALSE);
    data->framebuffer_pixels = saved_pixels;
    data->framebuffer_pitch = saved_pitch;
    return result;
}

static void OPENSTEP_GL_DeleteContext(_THIS, SDL_GLContext context)
{
    SDL_OpenStepGLContext *gl_context = (SDL_OpenStepGLContext *)context;

    (void)_this;
    /* This backend does not record which context a lease was taken under,
     * so a context going away ends any lease.  Conservative on purpose:
     * the cost is one window deciding again on its next swap. */
    OPENSTEP_GL_StampReleaseOwner();
    if (!gl_context) return;
    if (OSMesaGetCurrentContext() == gl_context->context) {
        gl_make_current(NULL, NULL);
    }
    OPENSTEP_GL_RemoveContext(gl_context);
    OSMesaDestroyContext(gl_context->context);
    SDL_free(gl_context->pixels);
    SDL_free(gl_context);
}

static void OPENSTEP_PumpEvents(_THIS)
{
    NSEvent *event;
    NSAutoreleasePool *pool;

    /* SDL drives AppKit's event loop itself rather than NSApplicationMain.
       Bound autoreleased event/pasteboard objects to one SDL pump iteration,
       matching the lifetime normally supplied by an AppKit application loop. */
    pool = [[NSAutoreleasePool alloc] init];
    for (;;) {
        event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                    untilDate:[NSDate distantPast]
                                       inMode:NSDefaultRunLoopMode
                                      dequeue:YES];
        if (event == nil) break;
        [NSApp sendEvent:event];
    }
    [NSApp updateWindows];
    OPENSTEP_CheckClipboardUpdate(_this);
    [pool release];
}
