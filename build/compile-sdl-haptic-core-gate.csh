#!/bin/csh -f
# Compile the shared haptic API with SDL's standard no-device driver.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/haptic-core-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/haptic -I$build_root/src/joystick -I$build_root/src/thread"

if (! -r $build_root/src/haptic/SDL_haptic.c) then
    echo "compile-sdl-haptic-core-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
cc $cflags -c $build_root/src/haptic/SDL_haptic.c -o $object_root/1.o
if ($status != 0) exit 1
cc $cflags -c $build_root/src/haptic/dummy/SDL_syshaptic.c -o $object_root/2.o
if ($status != 0) exit 1
echo "compile-sdl-haptic-core-gate: PASS upstream generic plus dummy haptic objects (object only)"
