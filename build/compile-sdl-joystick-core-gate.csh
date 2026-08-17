#!/bin/csh -f
# Compile the complete shared joystick/game-controller core with SDL's
# standard no-device driver. This preserves the public API on OPENSTEP.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/joystick-core-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/joystick -I$build_root/src/joystick/hidapi -I$build_root/src/events -I$build_root/src/video -I$build_root/src/thread"
set sources = ($build_root/src/joystick/*.c $build_root/src/joystick/dummy/SDL_sysjoystick.c)
set number = 0

if (! -r $build_root/src/joystick/SDL_joystick.c) then
    echo "compile-sdl-joystick-core-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-joystick-core-gate: PASS $number upstream joystick/game-controller objects (object only)"
