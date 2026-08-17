# SDL 2.32.10 for OPENSTEP 4.2 — feasibility assessment

Updated: 2026-08-15  
Status: **conditional GO for a full SDL 2.32.10 OpenStep port; modern GPU
features require SDL-standard unavailable-platform behaviour, while OpenGL
uses the Mesa 3.4.2 compatibility path**

## Evidence boundary

OPENSTEP hardware has supplied the compiler/framework inventory and selected
SDL2 core target evidence (see `notes/TARGET_INVENTORY_20260815.md`). The
remaining groups are still source inspection plus the existing real-hardware
SDL 1.2 record in `../openstep-sdl12/`. This remains a phased port, not a
runtime certification of the final `libSDL2.a`.

| Item | Basis | Result |
|---|---|---|
| SDL baseline | `release-2.32.10`, commit `5d249570393f7a37e037abf22cd6012a4cc56a71` | Fixed, reproducible source target |
| Native AppKit/DPS presentation | finished SDL 1.2 port | reusable design and behaviour, not source-compatible code |
| Native audio | finished SDL 1.2 SoundKit FCFS queue | feasible to reimplement behind SDL 2 audio-device API |
| timer/threads | finished SDL 1.2 BSD + Mach cthreads backend | feasible, but SDL 2 TLS/atomic semantics add work |
| Mesa 3D baseline | official Mesa 3.4.2 source archive, SHA-256 `b02b5f77321175820b9955b07979d9f8c5d52e146eecc719844380ef2849ddd6` | explicit `make openstep`, OSMesa, historical AppKit examples and no LLVM/llvmpipe source |
| initial target compatibility gate | target-side SDL public-header and `SDL_error.c` smoke | passed with an OPENSTEP type/configuration overlay; no SDL library archive has passed yet |
| atomic fallback gate | target-side link/run of SDL2 non-`__sync` atomic path | passed for single-threaded Set/Add/Get/CAS after an i486-specific spin hint fix; threaded contention remains unverified |
| cthreads primitive gate | target-side create/join/mutex standalone program | passed through the default target linker; SDL2 lifecycle, TLS and contention work remain |
| SDL2 cthreads backend gate | target-side native thread, mutex, semaphore, condition and public TLS lifecycle smoke | passed for native create/join/status/ID, recursive TryLock, two-worker mutex contention, semaphore TryWait/finite-timeout/wait-post, condition timeout/signal/broadcast, and real allocator-backed public create/wait with TLS cleanup; full `SDL_Init`/timer integration remains |
| SDL2 timer core gate | target-side `gettimeofday`/`select` backend plus actual SDL timer thread | passed for ticks, performance counter/frequency, interrupted-delay-capable primitive, timer create/callback/quit and tick reinitialization; full `SDL_Init` integration and controlled wall-clock regression evidence remain |

## What can be ported

SDL 2 has a clean software route.  A video backend provides a native window
and the three framebuffer operations `CreateWindowFramebuffer`,
`UpdateWindowFramebuffer`, and `DestroyWindowFramebuffer`.  SDL's existing
software renderer obtains that surface with `SDL_GetWindowSurface()` and
publishes it through `SDL_RenderPresent()`.  Therefore an AppKit `NSWindow` /
`NSView` + Display PostScript bitmap presenter can support both:

- SDL window-surface applications; and
- the standard `SDL_Renderer` **software** backend, including textures,
  blending, primitives, target textures and present.

This is more useful than an SDL 1.2-style surface-only port, because it
supports the dominant portable 2D SDL2 programming model without an OpenGL
dependency.  The SDL 1.2 row-orientation, dirty-rectangle, resize, NSEvent
translation, cursor and SoundKit queue findings are directly applicable at
the design level.

The final port must retain these public APIs. Desktop fullscreen and exclusive display switching,
Vulkan, Metal, HIDAPI, haptics, joystick, relative mouse/grab, shaped windows,
high-DPI, dynamic loading, clipboard, UTF-8 text input, drop files, multiple
windows and message boxes each require an OpenStep backend or SDL-standard
unavailable-device/result behaviour; none may be omitted from the final
archive merely because it is not an initial backend slice.

## Main blocker: current SDL2 versus the OPENSTEP compiler

The verified SDL 1.2 target compiler is NeXT `cc-744.13` (GCC 2.7.2.1) with a
C89 baseline and legacy Objective-C runtime.  The SDL 1.2 port explicitly
avoided C99 headers/types and `//` comments for this reason.

SDL 2.32.10 has substantially newer source assumptions: its source/include
tree contains thousands of C99-or-newer lexical uses and uses APIs such as
`stdint.h`, `stdint`-derived public types, `inline`, compiler builtins,
thread-local storage in its allocator path, atomics and a modern
CMake/autoconf build system.  Some features have fallbacks, but the release
is not an out-of-the-box GCC 2.7/C89 build.

This does not make a port impossible.  It makes the project a maintained
**compiler-compatibility fork** rather than a small platform backend.  Before
any feature port, the project must demonstrate that a selected minimal SDL2
source set compiles with `cc -m486` after a narrowly reviewed compatibility
overlay.  If this requires broad, unreviewable C99-to-C89 rewriting, use the
last SDL2 release proven compatible with the toolchain instead of claiming
the current release.

## Mesa 3.4.2 assessment and selection

The supplied Mesa 3.4.1 repository establishes the historical approach:
`docs/README.OpenStep` says the GL/GLU port was tested on OPENSTEP 4.2 Intel
and works by using Mesa's off-screen renderer to create bitmaps displayed by
an application view.  Its `OpenStep/MesaView/MesaView.m` implements exactly
that pattern:

1. allocate a client RGBA buffer;
2. create `OSMesaContext` and call `OSMesaMakeCurrent`;
3. render in software; and
4. wrap the buffer in `NSBitmapImageRep` and draw it.

Mesa 3.4.2 is the selected stable source.  It retains `docs/README.OpenStep`,
the full `OpenStep/` AppKit example tree, and a real `openstep` rule in
`Make-config`.  That rule compiles `OSmesa/osmesa.c` with
`-traditional-cpp -DOPENSTEP -O4` into static `libGL.a` and `libGLU.a` using
`mklib.openstep`; in this release the OSMesa entry points are part of
`libGL.a`, not a separate `libOSMesa.a`.  The complete source has no LLVM or
llvmpipe file/name.

Mesa 3.4.2 exposes OpenGL 1.1/1.2-era headers plus extensions.  It is not an
on-screen GLX, WGL, CGL, EGL or hardware-accelerated driver; it has no swap
interval, modern context-profile, shader, framebuffer-object, OpenGL ES or
Vulkan contract.

Consequently it can support the required **legacy OpenGL 1.2-compatible,
software-only SDL path**. It cannot satisfy applications needing modern
SDL2 OpenGL (normally GL 2.x+/GLSL), GLES, accelerated presentation or
reliable contemporary game performance.  It also cannot simply be enabled
as SDL2's OSMesa backend: SDL 2.32.10 has OSMesa configuration symbols but no
matching OSMesa video implementation; the OpenStep backend must implement
SDL's `GL_LoadLibrary`, `GL_GetProcAddress`, `GL_CreateContext`,
`GL_MakeCurrent`, `GL_SwapWindow` and `GL_DeleteContext` semantics itself.

The safer first 3D architecture is therefore:

```text
SDL_WINDOW_OPENGL (explicit opt-in)
  -> OpenStep SDL video backend
     -> Mesa 3.4.2 OSMesa context + SDL-owned RGBA buffer
        -> SDL_GL_SwapWindow: flush / dirty present through existing DPS view
```

Context sharing, double-buffer emulation, window resize, one-current-context
per cthread, pixel format, top/bottom row orientation, `glGetProcAddress`,
and AppKit redraw must each be proven by tests.  No GL feature above the
observed Mesa header may be advertised.

## Decision and gates

Proceed only in these phases, in order:

1. **Compiler gate (blocking):** compile an explicitly marked prototype core
   with no X11/pthreads/modern build tool dependency; do not mistake it for
   the final port.
2. **2D native gate:** one AppKit window, framebuffer surface, resize/expose,
   keyboard/mouse/quit and SDL software renderer run correctly.
3. **Core services gate:** SoundKit audio callback, timer, cthreads, TLS and
   atomic stress tests pass.
4. **Standard GL gate:** build Mesa 3.4.2/OSMesa, create an
   SDL GL context, render an OpenGL 1.2 triangle, swap/present, resize and
   destroy it without memory or context-lifetime faults.
5. **Compatibility gate:** unmodified small SDL2 2D programs and a
   deliberately GL-1.x-only program run on target; unsupported APIs fail
   explicitly and are documented.

Failure of gate 4 does not block the 2D SDL2 port.  Failure of gate 1 blocks
using SDL 2.32.10 as the baseline and requires a version/toolchain decision.
