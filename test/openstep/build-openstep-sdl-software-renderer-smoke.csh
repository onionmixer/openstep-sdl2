#!/bin/csh -f
# Link the real dispatcher closure and run SDL's upstream software renderer
# against an in-memory SDL surface; no WindowServer connection is made.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/openstep-sdl-software-renderer-smoke.c
set test_binary = /tmp/SDL20/bin/openstep-sdl-software-renderer-smoke

if (! -r $build_root/SDL-init-closure-gate.o) then
    echo "build-openstep-sdl-software-renderer-smoke: run link-sdl-init-closure-gate.csh first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/render -I$build_root/src/render/software -I$build_root/src/video -I$build_root/src/thread $test_source $build_root/SDL-init-closure-gate.o -framework AppKit -framework Foundation -framework SoundKit -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
$test_binary
if ($status != 0) exit 1
echo "build-openstep-sdl-software-renderer-smoke: PASS $test_binary"
