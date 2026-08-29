# OPENSTEP SDL2 2.32.10 — openstep.2

Second OPENSTEP 4.2 Intel i486 release of upstream SDL 2.32.10.

**This release is about OpenGL on a Matrox G450.** With the accelerated Mesa
from the [Matrox G450 driver](https://github.com/onionmixer/openstep-matrox-remade),
a spinning teapot at 800x600 went from **0.54 frames a second to 43.9**, and
the frame stopped crossing the bus at all. Everything else is unchanged, and
a build with stock Mesa behaves exactly as openstep.1 did.

## What changed

### The GL backend was giving the accelerated surface back, every bind

`OPENSTEP_GL_MakeCurrent` called `OSMesaPixelStore(OSMESA_Y_UP, 0)`. The
accelerated Mesa refuses a top-down context and hands its video-memory
surface back when it sees one, so **the card drew nothing**: every frame was
software, and nobody could tell, because a software frame is a correct frame.

`OSMESA_Y_UP` is context state rather than bind state, so it is now set to 1
explicitly after *every* successful `OSMesaMakeCurrent`, not left to Mesa's
creation default.

### SDL2 can now put a GL frame on the screen without reading it back

Delivering an accelerated frame the ordinary way means copying video memory
into system memory first — measured here at 746 ns per pixel, and it happens
once per rendering batch rather than once per frame. For one teapot at
320x240 that was 32 copies a frame and **99.9% of the frame time**.

An application can now hand SDL2 the driver's own present functions, and SDL2
delivers the frame video-memory-to-video-memory instead:

```c
#include <SDL_openstepglpresent.h>          /* new in this release */

static const SDL_OpenStepGLPresent hooks = {
    SDL_OPENSTEP_GLPRESENT_ABI, sizeof(hooks),
    OSMGAMesaBufferOrigin,
    OSMGAMesaBufferPresentMode,
    OSMGAMesaBufferPresentRect
};
SDL_SetWindowData(window, SDL_OPENSTEP_GLPRESENT_KEY, (void *)&hooks);
```

After that the draw/swap loop does not change. SDL2 owns the rectangle
arithmetic, the row order and every condition under which it must stand down.

**Why the application has to hand them over:** `libSDL2.a` must keep linking
against a stock Mesa, where those functions do not exist, so SDL2 cannot name
them. It calls plain function pointers instead. **No public SDL symbol was
added** — the archive still exports exactly 836.

**It is opt-in for a second reason.** A direct present is not compositing:
the window server does not know those pixels exist. Registering changes who
owns a piece of screen, which is not something to infer from a link line.

### What SDL2 does with it

- Falls back to the ordinary AppKit path whenever it must: no registration,
  a stock Mesa, no accelerated surface, the window hidden, minimised,
  unfocused or moved this frame, a destination off-screen, a refusal from the
  driver, a resize, a context change, or the application unregistering.
- Classifies refusals rather than logging them: engine busy is this frame,
  a destination that left the screen is until it returns, and anything the
  next frame cannot fix stops the window stamping for good.
- Leases the screen to **one window at a time**, because the driver's surface
  and present mode are per process rather than per context.
- Stops painting the AppKit bitmap over a live stamp on expose. That bitmap
  is not refreshed while stamping, so drawing it would put a stale picture
  over the frame.

### Row order

The accelerated surface is written bottom-up and the screen is scanned
top-down, so a single blit of the whole rectangle arrives upside down. A demo
can swap its own projection; a library cannot, because the projection belongs
to the application. SDL2 therefore stamps a row at a time in reverse:
8.01 ms against 3.69 for one blit at 800x600 — 43.9 frames a second against
54.6, and against 0.54 for the readback it replaces.

## Measured

Same `libSDL2.a`, same demo source, on a Matrox G450 at 60 Hz.

| build | registered | delivery | wall | fps | readbacks |
| --- | --- | --- | --- | --- | --- |
| stock `libGL.a` | — | AppKit swap | 16.06 ms | 62.26 | none |
| `libGL_mga.a` | no | AppKit swap | 1847.43 ms | 0.54 | 32 a frame |
| `libGL_mga.a` | yes | SDL2's VRAM stamp | 22.77 ms | 43.91 | **0** |

The first row is 320x240 and the last is 800x600; the middle row is 320x240
because 800x600 on that path is about eleven seconds a frame.

**Stock Mesa was never the slow one.** It renders straight into the caller's
array, so there is no readback to remove — which is why the first row is
unchanged from openstep.1 and why registering nothing must stay the default.

## New tests

- `openstep-sdl-gl-orientation` — four quadrants, four colours, through the
  2D path and the GL path, software and accelerated. Nothing in this port
  had ever checked which way up a frame arrives; the GL tests clear a window
  to one colour or read back with `glReadPixels`, which answers in GL's own
  coordinates and cannot see the presentation copy at all.
- `openstep-sdl-gl-stampfallback` — five stamped frames, then the hooks are
  removed and a swap happens **with nothing redrawn**. The window must still
  show the last frame.

## Installer packages

Install all selected packages at the same relocatable prefix, normally
`/LocalDeveloper`.

- `OpenStepSDL2Libraries.pkg` — static `libSDL2.a`.
- `OpenStepSDL2Headers.pkg` — public headers, `SDL_openstepglpresent.h`, and
  development documentation.
- `OpenStepSDL2Demos.pkg` — demo source, assets, rebuild scripts and i386
  binaries.

Extract the outer `.pkg.tar.gz` and open the contained `.pkg` with OPENSTEP
Installer.

## Verification included in this release

- The Libraries archive exposes all 836 required public SDL2 API symbols —
  the same 836 as openstep.1 — and contains only i386 Mach-O members.
- The native package verifier checks split payloads, i386 BOM visibility and
  installation hooks.
- `SDL_openstepglpresent.h` is present in the Headers BOM.

## Scope and limitations

- Intel i486 OPENSTEP 4.2 only.
- The direct present needs the Matrox G450 driver's accelerated Mesa. Without
  it nothing registers and nothing changes.
- A stamp is not compositing. A menu or a panel can cover the rectangle
  without taking focus, and SDL2 cannot see that; focus is the proxy it has.
  A window being dragged stands its stamp down, but SDL's window position is
  a cache that lags the server, so a fast drag can still show a stale
  rectangle for a frame.
- Recovering the window after an expose costs one frame: the stamp repaints
  it on the next swap rather than immediately.
