# Mesa dependency selection record

Updated: 2026-08-15

## Selected baseline: Mesa 3.4.2

- Archive: `https://archive.mesa3d.org/older-versions/3.x/MesaLib-3.4.2.tar.gz`
- SHA-256: `b02b5f77321175820b9955b07979d9f8c5d52e146eecc719844380ef2849ddd6`
- Release: stable Mesa 3.4 maintenance release.
- Direct source evidence:
  - `docs/README.OpenStep` names OPENSTEP 4.2 Intel as compiled/tested and
    prescribes `make openstep`.
  - `Make-config` target `openstep` selects `OSmesa/osmesa.c`, static
    `libGL.a`, `libGLU.a`, `-traditional-cpp -DOPENSTEP -O4` and
    `bin/mklib.openstep`.
  - The release retains `OpenStep/` including the AppKit `MesaView` example.
  - `include/GL/gl.h` declares OpenGL 1.1 and 1.2, not a modern GL profile.
  - Full-tree search finds no `llvm`/`llvmpipe` file or textual dependency.

Mesa 3.4.2 is the sole approved Mesa dependency for this plan.  Its OSMesa
symbols are linked from `libGL.a` in this release; the SDL2 build must not
expect a separate `libOSMesa.a`. It is the required legacy OpenGL path for
the standard SDL GL API.

## Target evidence (2026-08-15)

- The archived source above was SHA-256 verified before import.  The complete
  expanded tree and the original gzip archive are retained under `upstream/`.
- On OPENSTEP 4.2 i486, the historical command
  `make CC='cc -m486' openstep` completed in the private persistent stage
  `/tmp/SDL20/mesa/Mesa-3.4.2` and created static `lib/libGL.a` and
  `lib/libGLU.a`.
- `ar t lib/libGL.a` contains `osmesa.o`; the corresponding object exports
  `_OSMesaCreateContext`.
- A private, subtype-corrected i486 executable created an OSMesa RGBA
  context, bound a caller-owned buffer, cleared it, checked its pixels and
  reported `GL_VERSION=1.2 Mesa 3.4.2`.

This establishes the legacy Mesa dependency and off-screen GL execution only.
It does not yet establish any SDL `SDL_GL_*` function, AppKit presentation,
window resize rebinding or on-screen rendering claim.

## Rejected classes

- Current Mesa/llvmpipe: LLVM runtime/JIT dependency and modern build/runtime
  requirements are incompatible with the OPENSTEP target.
- Mesa versions with OSMesa but no directly verified OPENSTEP target: not a
  valid baseline.  OSMesa alone does not prove historical AppKit/cc support.
- Any on-screen GLX/EGL path: OPENSTEP SDL2 must present through its native
  AppKit/DPS backend, not introduce X11 or a modern window-system ABI.
