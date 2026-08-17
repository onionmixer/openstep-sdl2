#!/bin/csh -f
# Compile one non-overlapping set of the common SDL2 support implementation.
# This uses upstream SDL_stdlib.c, not the older prototype-only compat file.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/core-support-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread -I$build_root/src/timer"
set sources = (src/SDL_dataqueue.c src/SDL_error.c src/SDL_hints.c src/SDL_list.c src/SDL_log.c src/SDL_utils.c src/atomic/SDL_atomic.c src/atomic/SDL_spinlock.c src/stdlib/SDL_malloc.c src/stdlib/SDL_stdlib.c src/stdlib/SDL_string.c src/stdlib/SDL_getenv.c src/stdlib/SDL_iconv.c src/thread/SDL_thread.c src/thread/openstep/SDL_systls.c src/thread/openstep/SDL_systhread.c src/thread/openstep/SDL_sysmutex.c src/thread/openstep/SDL_syssem.c src/thread/openstep/SDL_syscond.c src/timer/SDL_timer.c src/timer/SDL_systimer.c)
set number = 0

if (! -r $build_root/src/SDL_dataqueue.c) then
    echo "compile-sdl-core-support-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $build_root/$source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-core-support-gate: PASS $number upstream/common objects (object only)"
