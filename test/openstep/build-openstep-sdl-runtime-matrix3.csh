#!/bin/csh -f
# Run a third ten-path common-runtime matrix with SDL's dummy audio driver.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/openstep-sdl-runtime-matrix3.c
set test_binary = /tmp/SDL20/bin/openstep-sdl-runtime-matrix3

if (! -r $build_root/SDL-init-closure-gate.o) then
    echo "build-openstep-sdl-runtime-matrix3: run link-sdl-init-closure-gate.csh first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/audio -I$build_root/src/events -I$build_root/src/render -I$build_root/src/render/software -I$build_root/src/thread -I$build_root/src/timer -I$build_root/src/video $test_source $build_root/SDL-init-closure-gate.o -framework AppKit -framework Foundation -framework SoundKit -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
setenv SDL_AUDIODRIVER dummy
$test_binary
if ($status != 0) exit 1
echo "build-openstep-sdl-runtime-matrix3: PASS ten additional runtime paths"
