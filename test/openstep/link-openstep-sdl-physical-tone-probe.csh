#!/bin/csh -f
# Link the short physical SoundKit tone probe through final libSDL2.a.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set mesa = /tmp/SDL20/mesa/Mesa-3.4.2
set archive = $build_root/libSDL2.a
set test_source = /tmp/SDL20/src/test/openstep/openstep-sdl-physical-tone-probe.c
set test_binary = /tmp/SDL20/bin/openstep-sdl-physical-tone-probe

if (! -r $archive || ! -r $mesa/lib/libGL.a) then
    echo "link-openstep-sdl-physical-tone-probe: build libSDL2.a and Mesa first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/audio -I$build_root/src/events -I$build_root/src/video -I$build_root/src/thread $test_source $archive -L$mesa/lib -lGL -lm -framework AppKit -framework Foundation -framework SoundKit -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
echo "link-openstep-sdl-physical-tone-probe: PASS $test_binary (run through GCD)"
