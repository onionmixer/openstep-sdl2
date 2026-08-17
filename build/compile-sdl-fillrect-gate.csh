#!/bin/csh -f
# Compile the upstream SDL2 software surface-fill implementation used by the
# standard renderer and public SDL_FillRect(s) API.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-fillrect-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/render -I$build_root/src/thread"

if (! -r $build_root/src/video/SDL_fillrect.c) then
    echo "compile-sdl-fillrect-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
rm -f $object
cc $cflags -c $build_root/src/video/SDL_fillrect.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-fillrect-gate: PASS $object (object only)"
