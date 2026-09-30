# SDL2 for OPENSTEP 4.2

This project ports upstream SDL **2.32.10**
(`release-2.32.10`, commit `5d249570393f7a37e037abf22cd6012a4cc56a71`) to
OPENSTEP 4.2. It does not define a reduced or OpenStep-specific public SDL
API. The final deliverable is `libSDL2.a` with the selected upstream SDL2
public API and target-appropriate SDL semantics.

The implementation plan is [PORT_PLAN.md](PORT_PLAN.md), and the public API
completion contract is [notes/API_COVERAGE.md](notes/API_COVERAGE.md). Mesa
3.4.2 supplies the planned standard SDL OpenGL 1.2 path because it retains an
OPENSTEP static-library target and has no LLVM dependency.

The target evidence is recorded in
[notes/TARGET_INVENTORY_20260815.md](notes/TARGET_INVENTORY_20260815.md).
The final i386 `libSDL2.a` passes the 836-symbol public API archive check.

## Installer delivery status

The target build produces three independently installable packages at one
prefix (normally `/LocalDeveloper`):

- `OpenStepSDL2Libraries.pkg` — `libSDL2.a` only.
- `OpenStepSDL2Headers.pkg` — public headers and documentation.
- `OpenStepSDL2Demos.pkg` — rebuildable port/upstream example source, assets
  and i386 demo binaries.

All three packages have been installed and their installed demo source has
been rebuilt using only `/LocalDeveloper` headers and libraries.  The detailed
contract is
[release-packaging/SPLIT_PACKAGE_CONTRACT.md](release-packaging/SPLIT_PACKAGE_CONTRACT.md).

**Latest release: `v2.32.10-openstep.5`** —
[release notes](RELEASE_NOTES_v2.32.10-openstep.5.md).

## Accelerated OpenGL on a Matrox G450

With the accelerated Mesa from the
[Matrox G450 driver](https://github.com/onionmixer/openstep-matrox-remade),
the card draws and the frame need never enter system memory.  An application
hands SDL2 the driver's present functions once:

```c
#include <SDL_openstepglpresent.h>

static const SDL_OpenStepGLPresent hooks = {
    SDL_OPENSTEP_GLPRESENT_ABI, sizeof(hooks),
    OSMGAMesaBufferOrigin, OSMGAMesaBufferPresentMode,
    OSMGAMesaBufferPresentRect
};
SDL_SetWindowData(window, SDL_OPENSTEP_GLPRESENT_KEY, (void *)&hooks);
```

and its draw/swap loop does not change.  A spinning teapot at 800x600 runs at
**43.9 frames a second** instead of 0.54.

It is opt-in, and stays opt-in for two reasons: `libSDL2.a` must keep linking
against a stock Mesa, where those functions do not exist; and a direct present
is not compositing, so registering changes who owns a piece of the screen.
A program that registers nothing behaves exactly as it did.  No public SDL
symbol was added — the archive still exports exactly 836.

## Intended layout

```text
openstep-sdl20/
|-- README.md                 this scope statement
|-- FEASIBILITY.md            evidence, conclusion, risks and gates
|-- PORT_PLAN.md              active target-first implementation plan
|-- PLAN_SDL20.md             original high-level phased outline
|-- notes/                    source inventories and target evidence
|-- upstream/                 verified pristine SDL 2.32.10 source and record
|-- port/openstep/            OPENSTEP compatibility overlay (bootstrap only)
|-- build/                    safe target staging and overlay scripts
`-- test/openstep/            target compiler gates and runtime regressions
```

The imported upstream source remains pristine. Target-specific changes live
under `port/openstep/` and are copied only into the private `/tmp/SDL20`
build overlay.
