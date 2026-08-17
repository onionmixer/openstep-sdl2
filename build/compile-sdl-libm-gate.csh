#!/bin/csh -f
# Compile SDL2's complete upstream uClibc-derived math fallback set.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/libm-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/libm"
set sources = ($build_root/src/libm/*.c)

if (! -r $build_root/src/libm/math_libm.h) then
    echo "compile-sdl-libm-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    cc $cflags -c $source -o $object_root/$source:t:r.o
    if ($status != 0) exit 1
end
echo "compile-sdl-libm-gate: PASS upstream SDL libm objects (object only)"
