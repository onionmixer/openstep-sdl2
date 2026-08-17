#!/bin/csh -f
# Compile the native AppKit/DPS boundary and SDL2's private video ABI.
# This is not a video driver or a window-success test.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set source_root = /tmp/SDL20/src
set object = $build_root/openstep-video-header-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/video/openstep"

if (! -r $build_root/src/video/openstep/SDL_openstepvideo.h) then
    echo "compile-openstep-video-header-gate: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $object
cc $cflags -c $source_root/test/openstep/openstep-video-backend-header.m -o $object
if ($status != 0) exit 1
echo "compile-openstep-video-header-gate: PASS $object (ABI boundary only)"
