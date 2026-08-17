#!/bin/csh -f
# Run a second ten-path matrix through the real SDL dispatcher. Dummy audio
# avoids SoundKit playback; the only file is a private /tmp RWops probe.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/openstep-sdl-runtime-matrix2.c
set test_binary = /tmp/SDL20/bin/openstep-sdl-runtime-matrix2

if (! -r $build_root/SDL-init-closure-gate.o) then
    echo "build-openstep-sdl-runtime-matrix2: run link-sdl-init-closure-gate.csh first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/audio -I$build_root/src/events -I$build_root/src/file -I$build_root/src/render -I$build_root/src/render/software -I$build_root/src/thread -I$build_root/src/timer -I$build_root/src/video $test_source $build_root/SDL-init-closure-gate.o -framework AppKit -framework Foundation -framework SoundKit -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
setenv SDL_AUDIODRIVER dummy
$test_binary
if ($status != 0) exit 1
echo "build-openstep-sdl-runtime-matrix2: PASS ten additional runtime paths"
