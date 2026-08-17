#!/bin/csh -f
# Compile SDL's standard BMP load/save implementation. It depends only on the
# already staged RWops, pixel and surface core; no OPENSTEP-specific image API
# is introduced.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-bmp-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/thread"

if (! -r $build_root/src/video/SDL_bmp.c) then
    echo "compile-sdl-bmp-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
rm -f $object
cc $cflags -c $build_root/src/video/SDL_bmp.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-bmp-gate: PASS $object (standard BMP load/save object)"
