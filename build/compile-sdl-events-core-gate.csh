#!/bin/csh -f
# Compile the upstream SDL2 event core used by the OPENSTEP AppKit driver.
# This is an object gate; remaining event module links are tracked separately.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/events-core-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/events -I$build_root/src/video -I$build_root/src/render -I$build_root/src/thread -I$build_root/src/timer"
set sources = (SDL_events.c SDL_keyboard.c SDL_mouse.c SDL_windowevents.c SDL_quit.c)
set number = 0

if (! -r $build_root/src/events/SDL_events.c) then
    echo "compile-sdl-events-core-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o

foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $build_root/src/events/$source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-events-core-gate: PASS $number objects (object only)"
