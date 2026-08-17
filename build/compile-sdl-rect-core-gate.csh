#!/bin/csh -f
# Compile the upstream SDL2 rectangle implementation used by surfaces/events.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-rect-core-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video"

if (! -r $build_root/src/video/SDL_rect.c) then
    echo "compile-sdl-rect-core-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
rm -f $object
cc $cflags -c $build_root/src/video/SDL_rect.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-rect-core-gate: PASS $object (object only)"
