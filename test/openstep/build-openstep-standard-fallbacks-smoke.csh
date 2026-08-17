#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/openstep-standard-fallbacks-smoke.c
set test_binary = /tmp/SDL20/bin/openstep-standard-fallbacks-smoke

if (! -r $build_root/src/power/SDL_power.c) then
    echo "build-openstep-standard-fallbacks-smoke: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -DSDL_ASSERT_LEVEL=0 -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/locale -I$build_root/src/power -I$build_root/src/thread -I$build_root/src/libm $test_source $build_root/src/loadso/dummy/SDL_sysloadso.c $build_root/src/filesystem/dummy/SDL_sysfilesystem.c $build_root/src/locale/SDL_locale.c $build_root/src/locale/dummy/SDL_syslocale.c $build_root/src/power/SDL_power.c $build_root/src/libm/*.c $build_root/src/thread/SDL_thread.c $build_root/src/thread/openstep/SDL_systls.c $build_root/src/thread/openstep/SDL_systhread.c $build_root/src/thread/openstep/SDL_sysmutex.c $build_root/src/timer/SDL_systimer.c $build_root/src/atomic/SDL_atomic.c $build_root/src/atomic/SDL_spinlock.c $build_root/src/stdlib/SDL_malloc.c $build_root/src/stdlib/SDL_stdlib.c $build_root/src/stdlib/SDL_string.c $build_root/src/stdlib/SDL_getenv.c $build_root/src/stdlib/SDL_iconv.c $build_root/src/SDL_hints.c $build_root/src/SDL_log.c $build_root/src/SDL_error.c -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
$test_binary
if ($status != 0) exit 1
echo "build-openstep-standard-fallbacks-smoke: PASS $test_binary"
