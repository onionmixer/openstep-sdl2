#!/bin/csh -f
# Compile the complete platform-independent SDL2 event subsystem. Platform
# drivers are deliberately kept separate; this verifies the shared queue,
# keyboard, mouse, touch, gesture, drop and quit implementations together.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/events-full-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/events -I$build_root/src/video -I$build_root/src/render -I$build_root/src/thread -I$build_root/src/timer"
set sources = ($build_root/src/events/*.c)
set number = 0

if (! -r $build_root/src/events/SDL_touch.c) then
    echo "compile-sdl-events-full-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-events-full-gate: PASS $number complete upstream event objects (object only)"
