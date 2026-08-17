#!/bin/csh -f
# Link non-GUI event-queue and timer dispatcher consumers through libSDL2.a.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set mesa = /tmp/SDL20/mesa/Mesa-3.4.2
set archive = $build_root/libSDL2.a
set events_source = /tmp/SDL20/src/test/openstep/openstep-sdl-events-queue-smoke.c
set timer_source = /tmp/SDL20/src/test/openstep/openstep-sdl-init-timer-smoke.c
set events_binary = /tmp/SDL20/bin/openstep-sdl-final-archive-events-smoke
set timer_binary = /tmp/SDL20/bin/openstep-sdl-final-archive-timer-smoke
set cflags = "-m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/events -I$build_root/src/video -I$build_root/src/thread"

if (! -r $archive) then
    echo "link-openstep-sdl-final-archive-dispatch-smokes: build libSDL2.a first"
    exit 2
endif

rm -f $events_binary $timer_binary
cc $cflags $events_source $archive -L$mesa/lib -lGL -lm -framework AppKit -framework Foundation -framework SoundKit -o $events_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $events_binary
if ($status != 0) exit 1
cc $cflags $timer_source $archive -L$mesa/lib -lGL -lm -framework AppKit -framework Foundation -framework SoundKit -o $timer_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $timer_binary
if ($status != 0) exit 1
echo "link-openstep-sdl-final-archive-dispatch-smokes: PASS event+timer binaries (not run)"
