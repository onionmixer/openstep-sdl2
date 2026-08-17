#!/bin/csh -f
# Compile upstream software blit/RLE/YUV/stretch sources for the SDL2 surface core.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/blit-core-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/render -I$build_root/src/thread"
set sources = (SDL_blit.c SDL_blit_0.c SDL_blit_1.c SDL_blit_A.c SDL_blit_N.c SDL_blit_auto.c SDL_blit_copy.c SDL_blit_slow.c SDL_RLEaccel.c SDL_yuv.c SDL_stretch.c yuv2rgb/yuv_rgb_std.c yuv2rgb/yuv_rgb_sse.c yuv2rgb/yuv_rgb_lsx.c)
set number = 0

if (! -r $build_root/src/video/SDL_blit.c) then
    echo "compile-sdl-blit-core-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $build_root/src/video/$source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-blit-core-gate: PASS $number objects (object only)"
