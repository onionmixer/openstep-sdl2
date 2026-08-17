#!/bin/csh -f
# Compile SDL2's common sensor API with its upstream no-device driver.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/sensor-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/sensor -I$build_root/src/events -I$build_root/src/thread"

if (! -r $build_root/src/sensor/dummy/SDL_dummysensor.c) then
    echo "compile-sdl-sensor-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
cc $cflags -c $build_root/src/sensor/SDL_sensor.c -o $object_root/SDL_sensor.o
if ($status != 0) exit 1
cc $cflags -c $build_root/src/sensor/dummy/SDL_dummysensor.c -o $object_root/SDL_dummysensor.o
if ($status != 0) exit 1
echo "compile-sdl-sensor-gate: PASS upstream generic plus dummy sensor objects (object only)"
