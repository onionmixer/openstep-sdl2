#!/bin/csh -f
# Compile SDL's public URL API with its standard unsupported dummy backend.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/misc-fallback-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/misc"

if (! -r $build_root/src/misc/dummy/SDL_sysurl.c) then
    echo "compile-sdl-misc-fallback-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
cc $cflags -c $build_root/src/misc/SDL_url.c -o $object_root/1.o
if ($status != 0) exit 1
cc $cflags -c $build_root/src/misc/dummy/SDL_sysurl.c -o $object_root/2.o
if ($status != 0) exit 1
echo "compile-sdl-misc-fallback-gate: PASS 2 upstream URL fallback objects (object only)"
