#!/bin/csh -f
# Compile standard SDL2 fallback implementations without removing their API.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/standard-fallback-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/locale -I$build_root/src/power"

if (! -r $build_root/src/locale/SDL_locale.c) then
    echo "compile-sdl-standard-fallbacks-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
cc $cflags -c $build_root/src/loadso/dummy/SDL_sysloadso.c -o $object_root/1.o
if ($status != 0) exit 1
cc $cflags -c $build_root/src/filesystem/dummy/SDL_sysfilesystem.c -o $object_root/2.o
if ($status != 0) exit 1
cc $cflags -c $build_root/src/locale/SDL_locale.c -o $object_root/3.o
if ($status != 0) exit 1
cc $cflags -c $build_root/src/locale/dummy/SDL_syslocale.c -o $object_root/4.o
if ($status != 0) exit 1
cc $cflags -c $build_root/src/power/SDL_power.c -o $object_root/5.o
if ($status != 0) exit 1
echo "compile-sdl-standard-fallbacks-gate: PASS 5 upstream fallback objects (object only)"
