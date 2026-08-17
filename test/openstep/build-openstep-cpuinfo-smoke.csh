#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/openstep-cpuinfo-smoke.c
set test_binary = /tmp/SDL20/bin/openstep-cpuinfo-smoke

if (! -r $build_root/src/cpuinfo/SDL_openstepcpuinfo.c) then
    echo "build-openstep-cpuinfo-smoke: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -DSDL_ASSERT_LEVEL=0 -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread $test_source $build_root/src/cpuinfo/SDL_openstepcpuinfo.c $build_root/src/thread/SDL_thread.c $build_root/src/thread/openstep/SDL_systls.c $build_root/src/thread/openstep/SDL_systhread.c $build_root/src/thread/openstep/SDL_sysmutex.c $build_root/src/timer/SDL_systimer.c $build_root/src/atomic/SDL_atomic.c $build_root/src/atomic/SDL_spinlock.c $build_root/src/stdlib/SDL_malloc.c $build_root/src/stdlib/SDL_string.c $build_root/src/stdlib/SDL_getenv.c $build_root/src/stdlib/SDL_iconv.c $build_root/src/stdlib/SDL_stdlib_compat.c $build_root/src/SDL_hints.c $build_root/src/SDL_log.c $build_root/src/SDL_error.c -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
$test_binary
if ($status != 0) exit 1
echo "build-openstep-cpuinfo-smoke: PASS $test_binary"
