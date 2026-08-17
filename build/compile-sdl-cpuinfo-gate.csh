#!/bin/csh -f
# Compile OPENSTEP's i386 CPU information implementation. NeXT cc marks the
# generic SDL x86 CPUID unit as i586, which OPENSTEP's i386 loader rejects.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/cpuinfo-objects
set cflags = "-m486 -arch i386 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src"

if (! -r $build_root/src/cpuinfo/SDL_openstepcpuinfo.c) then
    echo "compile-sdl-cpuinfo-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
cc $cflags -c $build_root/src/cpuinfo/SDL_openstepcpuinfo.c -o $object_root/SDL_cpuinfo.o
if ($status != 0) exit 1
file $object_root/SDL_cpuinfo.o | grep i386 > /dev/null
if ($status != 0) then
    echo "compile-sdl-cpuinfo-gate: non-i386 CPU information object"
    file $object_root/SDL_cpuinfo.o
    exit 1
endif
echo "compile-sdl-cpuinfo-gate: PASS OPENSTEP/i386 CPU information object"
