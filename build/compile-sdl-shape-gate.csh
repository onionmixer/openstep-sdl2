#!/bin/csh -f
# Compile SDL's common shaped-window API. OPENSTEP intentionally supplies no
# shape driver, so normal public calls report the upstream nonshapeable result
# instead of disappearing from the static archive.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-shape-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/thread"

if (! -r $build_root/src/video/SDL_shape.c || ! -r $build_root/src/video/SDL_shape_internals.h) then
    echo "compile-sdl-shape-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
rm -f $object
cc $cflags -c $build_root/src/video/SDL_shape.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-shape-gate: PASS $object (standard unsupported-shape API object)"
