#!/bin/csh -f
# Link the standard SDL2 pixel-format smoke; it is safe over telnet.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set mesa = /tmp/SDL20/mesa/Mesa-3.4.2
set test_source = /tmp/SDL20/src/test/openstep/openstep-sdl-pixel-format-smoke.c
set test_binary = /tmp/SDL20/bin/openstep-sdl-pixel-format-smoke

if (! -r $build_root/SDL-init-closure-gate.o) then
    echo "link-openstep-sdl-pixel-format-smoke: build the SDL closure first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/events -I$build_root/src/render -I$build_root/src/video -I$build_root/src/thread $test_source $build_root/SDL-init-closure-gate.o -L$mesa/lib -lGL -lm -framework AppKit -framework Foundation -framework SoundKit -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
echo "link-openstep-sdl-pixel-format-smoke: PASS $test_binary"
