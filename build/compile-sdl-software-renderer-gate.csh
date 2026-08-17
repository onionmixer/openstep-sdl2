#!/bin/csh -f
# Compile the complete upstream common/software SDL2 renderer. This is the
# standard fallback 2D renderer; it does not select a Mesa/OpenGL backend.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/software-renderer-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/render -I$build_root/src/render/software -I$build_root/src/video -I$build_root/src/thread"
set sources = ($build_root/src/render/SDL_render.c $build_root/src/render/SDL_yuv_sw.c $build_root/src/render/software/*.c)
set number = 0

if (! -r $build_root/src/render/software/SDL_render_sw.c) then
    echo "compile-sdl-software-renderer-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-software-renderer-gate: PASS $number upstream common/software renderer objects (object only)"
