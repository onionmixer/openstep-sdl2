#!/bin/csh -f
# Compile the upstream SDL video core after applying the OPENSTEP bootstrap.
# This produces no archive and does not assert that window/event services work.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-video-core-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/render -I$build_root/src/thread -I$build_root/src/timer"

if (! -r $build_root/src/video/SDL_video.c) then
    echo "compile-sdl-video-core-gate: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $object
cc $cflags -c $build_root/src/video/SDL_video.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-video-core-gate: PASS $object (object only)"
