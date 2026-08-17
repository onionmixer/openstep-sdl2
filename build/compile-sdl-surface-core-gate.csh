#!/bin/csh -f
# Compile the upstream SDL2 surface/pixel core used by the OPENSTEP framebuffer.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/surface-core-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/render -I$build_root/src/thread"
set sources = (SDL_pixels.c SDL_surface.c)
set number = 0

if (! -r $build_root/src/video/SDL_surface.c) then
    echo "compile-sdl-surface-core-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $build_root/src/video/$source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-surface-core-gate: PASS $number objects (object only)"
