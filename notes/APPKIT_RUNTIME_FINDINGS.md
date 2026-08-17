# OPENSTEP 4.2 AppKit runtime findings

This note records target evidence for the native SDL2 AppKit backend.  It is
not a Linux or modern Cocoa compatibility assumption.

## Primary documentation on the target

The OPENSTEP system itself provides the relevant reference material under
`/NextLibrary/Frameworks/AppKit.framework/Resources/English.lproj/Documentation/Reference/Classes/`.
The consulted classes were `NSEvent`, `NSResponder`, `NSApplication`,
`NSPanel`, `NSControl`, `NSButton`, and `NSWindow`.

`NSEvent.h` defines only left/right mouse button event types.  It has no
wheel or `NSOtherMouse*` event type.  Its documented device-independent
modifier flags include Shift, Control, Alternate, Command, Alpha Shift,
Numeric Pad, Help and Function.

## SDL2 mouse compatibility baseline

The OpenStep backend is deliberately a port of SDL2's standard mouse API;
it does not add an OpenStep-specific mouse interface or invent events which
the public AppKit contract cannot supply.  The platform baseline is:

| Physical/AppKit capability | SDL2 result |
|---|---|
| left button (`mouseDown:` / `mouseUp:` / `mouseDragged:`) | supported as `SDL_BUTTON_LEFT` (1) |
| right button (`rightMouseDown:` / `rightMouseUp:` / `rightMouseDragged:`) | supported as `SDL_BUTTON_RIGHT` (3) |
| middle button / additional buttons | unavailable: no public OpenStep 4.2 `NSEvent` type or responder path; no synthetic SDL button 2 or higher event |
| wheel / scroll wheel button | unavailable: no public wheel event type; no synthetic `SDL_MOUSEWHEEL` event |

This is a capability boundary of the public OPENSTEP 4.2 AppKit API, not a
claim that underlying hardware cannot have three buttons.  Supporting a
third button would require a separately validated, non-AppKit low-level input
interface and must not be represented as completed by this AppKit backend.

## Event delivery rules used by the backend

`NSApplication` retrieves queued events with
`nextEventMatchingMask:untilDate:inMode:dequeue:` and sends them through the
responder chain with `sendEvent:`.  SDL's nonblocking AppKit pump uses this
documented sequence with `NSDefaultRunLoopMode` and then calls
`updateWindows`.

`NSEvent` permits `characters`, `charactersIgnoringModifiers`, and `keyCode`
only for key-up/key-down events.  Calling them from a mouse responder raises
an exception.  The raw input probe therefore records mouse data with
`locationInWindow` and `clickCount` only.

For focused-window global mouse state, `NSWindow` documents
`mouseLocationOutsideOfEventStream` as the current mouse location in the
window's base coordinate system even with no pending event.  SDL converts that
point through its flipped content view before adding the SDL window origin.
The lower-level Display PostScript `PScurrentmouse` reference explicitly says
not to use it in an Application Kit application, so it is intentionally not
used by this backend.

For independent mouse focus, the SDL content view registers one documented
full-bounds tracking rectangle. `mouseEntered:` assigns the SDL mouse focus
and submits the converted location, while `mouseExited:` clears focus only if
that view still owns it. OPENSTEP documents tracking rectangles as static
`NSWindow` objects, so the backend removes and recreates its rectangle after
content resizing and whenever it reconstructs a native window for a style or
fullscreen transition. The automatic final-archive responder smoke passed
enter/exit focus and in-bounds motion; the lifecycle and cursor regressions
also passed through the resize/style reconstruction paths.

OPENSTEP console delivery can report modifier state only in `NSFlagsChanged`.
The SDL2 backend preserves those flags per video device and uses the saved
state for a following key event whose modifier flags are zero, following the
completed SDL1 port's proven approach.

## Physical text-drag probe behaviour

The dedicated physical `SDL_DROPTEXT` source view must return `YES` from the
public `NSView acceptsFirstMouse:` callback.  Without it, AppKit consumes the
first click on an inactive source window merely to activate that window; its
`mouseDown:` method does not run, so a first drag appears to do nothing and a
second attempt is required.  With that callback enabled, the 2026-08-17
physical run recorded its first `source mouseDown`, `source deposited=1`, and
the SDL sequence `SDL_DROPBEGIN` → `SDL_DROPTEXT` →
`SDL_DROPCOMPLETE`.  This is a source-probe interaction rule, not an SDL2
destination or event-translation limitation.

## Physical SDL window lifecycle

On 2026-08-17, a resizable real SDL window was moved, resized twice,
minimized through the Workspace dock, restored, and finally closed with
Escape. The target-local SDL record contained `SDL_WINDOWEVENT_MOVED`
(`314,437`), two `SDL_WINDOWEVENT_SIZE_CHANGED` /
`SDL_WINDOWEVENT_RESIZED` pairs (`650x474`, then `412x280`), followed by
`SDL_WINDOWEVENT_MINIMIZED`, `SDL_WINDOWEVENT_RESTORED`, the expected focus
loss/gain transitions, and a normal Escape keydown. Thus the observed AppKit
Workspace window-management path agrees with the automatic lifecycle tests.

On the same target session, a left-button drag produced a continuous
`SDL_MOUSEMOTION` sequence with state `0x1` (`SDL_BUTTON_LMASK`) between
`SDL_BUTTON_LEFT` down/up. A right-button drag independently produced motion
state `0x4` (`SDL_BUTTON_RMASK`) between `SDL_BUTTON_RIGHT` down/up. This is
physical confirmation of both `mouseDragged:` and `rightMouseDragged:`
translation, rather than only synthetic responder or click coverage.

## Modal panels and message boxes

The target's `NSButton` mouse tracking and target/action delivery are normal:
the native probe logged both Continue and Cancel action IDs.  The defect is
specific to this GCD context: `runModalForWindow:` did not return after an
action sent `stopModalWithCode:`.

The documented session form works:

1. `beginModalSessionForWindow:` creates and fronts the modal panel.
2. `runModalSession:` dispatches its queued events.
3. The button action records its selected index.
4. The caller observes that index, invokes `endModalSession:`, and orders the
   panel out.

SDL's native message-box backend consequently uses an `NSPanel` with ordinary
`NSButton` controls rather than `NSRunAlertPanel`.  It supports arbitrary
custom-button counts in three visual columns, standard Return/Escape default
button flags, and an implicit OK for a zero-button custom request.

Target GCD evidence passed: two custom buttons (ID 71), four custom buttons
(ID 104), zero custom buttons (implicit OK, ID -1), simple message boxes,
pre-`SDL_Init` bootstrap invocation, Return default, Escape default, and a
real SDL parent window.

## Input limitations observed on the current console path

An earlier physical right-click attempt reached the target as left-button
down/up.  After the 2026-08-16 console reboot, the final-archive SDL input
record probe received a real left click as `SDL_BUTTON_LEFT` (button 1) and a
real right click as `SDL_BUTTON_RIGHT` (button 3), each with matching down/up
events.  The backend's documented `rightMouseDown:`/`rightMouseUp:` selector
path is therefore physically confirmed on the current console route; the
earlier result was not treated as a permanent backend limitation. A physical
middle click produced no SDL button event, consistent with OPENSTEP 4.2's
public `NSEvent` declaration having only left/right mouse event types and no
`NSOtherMouse*` family.

The 2026-08-16 console route delivered no F1 key event, but a later physical
final-archive probe recorded F1–F4 as standard SDL scancodes 59–62 and arrows
as standard scancodes 80/79/82/81. OPENSTEP may reserve F1 or route it through
Help handling depending on the active OS-level shortcut/keymap, so an absent
F1 on one console configuration is pre-SDL input routing, not a backend reason
to fabricate an event. Applications receive ordinary SDL key events whenever
AppKit supplies them.

On 2026-08-17, physical Shift, Control and Alternate each produced their
expected SDL left-modifier press/release transitions through the final archive.
The same physical Command-key attempt produced no raw AppKit `NSFlagsChanged`,
`NSCommandKeyMask`, or key event: the raw probe recorded only the subsequent
Escape. Command therefore cannot be claimed as physically delivered on this
console keymap, but the absence occurs before SDL translation; the backend's
documented `NSCommandKeyMask` mapping remains covered by the synthetic
responder test.

The physical record also exposed function-character strings being emitted as
`SDL_TEXTINPUT` alongside navigation/function key events. The backend now
recognizes AppKit's private-use function-character range and suppresses those
text payloads while still sending the matching SDL scancode. `NSFunctionKeyMask`
and `NSNumericPadKeyMask` are AppKit event classifications, not SDL AltGr or
NumLock state: mapping them to `KMOD_MODE`/`KMOD_NUM` incorrectly tagged F- and
arrow-key events. The final archive ignores both classifications for SDL
modifier state; synthetic regression and physical left-arrow input verified
`mod=0x0000`. Ordinary `a` retains its SDL text event.
