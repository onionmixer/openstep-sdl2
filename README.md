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
The current target closure has substantial compiler and runtime evidence, but
it is a diagnostic `ld -r` artifact rather than a distributable SDL2 library.
No `libSDL2.a` is released until the complete public export and acceptance
gates in `notes/API_COVERAGE.md` pass.

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
