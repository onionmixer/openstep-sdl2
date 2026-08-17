#!/bin/csh -f
# Compile upstream src/SDL.c with the OPENSTEP overlay, but do not archive it.
# It is the first gate toward replacing the private bootstrap with SDL2's
# actual init/quit dispatcher; unresolved subsystem links are intentionally
# outside this object-only gate.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-init-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread -I$build_root/src/timer"

if (! -r $build_root/src/SDL.c) then
    echo "compile-sdl-init-gate: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $object
cc $cflags -c $build_root/src/SDL.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-init-gate: PASS $object (object only; not final SDL_Init)"
