#!/bin/csh -f
# Compile SDL2's real assertion implementation for the init-link closure.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-assert-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/thread"

if (! -r $build_root/src/SDL_assert.c) then
    echo "compile-sdl-assert-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
rm -f $object
cc $cflags -c $build_root/src/SDL_assert.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-assert-gate: PASS $object (object only)"
