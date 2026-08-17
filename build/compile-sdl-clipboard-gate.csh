#!/bin/csh -f
# Compile SDL's public clipboard dispatcher.  The OPENSTEP video backend
# supplies the native NSPasteboard callbacks; no API is stubbed out.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-clipboard-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video"

if (! -r $build_root/src/video/SDL_clipboard.c) then
    echo "compile-sdl-clipboard-gate: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $object
cc $cflags -c $build_root/src/video/SDL_clipboard.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-clipboard-gate: PASS $object (public clipboard dispatcher)"
