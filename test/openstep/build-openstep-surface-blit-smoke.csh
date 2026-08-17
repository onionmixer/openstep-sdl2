#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/openstep-surface-blit-smoke.c
set test_binary = /tmp/SDL20/bin/openstep-surface-blit-smoke

if (! -r $build_root/src/video/SDL_fillrect.c) then
    echo "build-openstep-surface-blit-smoke: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -DSDL_ASSERT_LEVEL=0 -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread -I$build_root/src/video -I$build_root/src/render -I$build_root/src/libm $test_source $build_root/src/SDL_list.c $build_root/src/video/SDL_rect.c $build_root/src/video/SDL_pixels.c $build_root/src/video/SDL_surface.c $build_root/src/video/SDL_fillrect.c $build_root/src/video/SDL_blit.c $build_root/src/video/SDL_blit_0.c $build_root/src/video/SDL_blit_1.c $build_root/src/video/SDL_blit_A.c $build_root/src/video/SDL_blit_N.c $build_root/src/video/SDL_blit_auto.c $build_root/src/video/SDL_blit_copy.c $build_root/src/video/SDL_blit_slow.c $build_root/src/video/SDL_RLEaccel.c $build_root/src/video/SDL_yuv.c $build_root/src/video/SDL_stretch.c $build_root/src/video/yuv2rgb/yuv_rgb_std.c $build_root/src/video/yuv2rgb/yuv_rgb_sse.c $build_root/src/video/yuv2rgb/yuv_rgb_lsx.c $build_root/src/libm/*.c $build_root/src/cpuinfo/SDL_openstepcpuinfo.c $build_root/src/thread/SDL_thread.c $build_root/src/thread/openstep/SDL_systls.c $build_root/src/thread/openstep/SDL_systhread.c $build_root/src/thread/openstep/SDL_sysmutex.c $build_root/src/timer/SDL_systimer.c $build_root/src/atomic/SDL_atomic.c $build_root/src/atomic/SDL_spinlock.c $build_root/src/stdlib/SDL_malloc.c $build_root/src/stdlib/SDL_stdlib.c $build_root/src/stdlib/SDL_string.c $build_root/src/stdlib/SDL_getenv.c $build_root/src/stdlib/SDL_iconv.c $build_root/src/SDL_hints.c $build_root/src/SDL_log.c $build_root/src/SDL_error.c -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
$test_binary
if ($status != 0) exit 1
echo "build-openstep-surface-blit-smoke: PASS $test_binary"
