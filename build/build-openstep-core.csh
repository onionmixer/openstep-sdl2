#!/bin/csh -f
# Build the explicitly bounded, headless SDL2 compiler-gate archive.
# This is not the final SDL2 port and must not be installed or named libSDL2.a.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/core-objects
set archive = $build_root/libSDL2-core-prototype.a
set cflags = "-m486 -O -Wall -DSDL_ASSERT_LEVEL=0 -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread -I$build_root/src/timer"
set nonomatch
set objects = ()
set number = 0
set sources = (src/SDL_error.c src/SDL_hints.c src/SDL_log.c src/atomic/SDL_atomic.c src/atomic/SDL_spinlock.c src/stdlib/SDL_malloc.c src/stdlib/SDL_string.c src/stdlib/SDL_getenv.c src/stdlib/SDL_iconv.c src/stdlib/SDL_stdlib_compat.c src/thread/SDL_thread.c src/thread/openstep/SDL_systls.c src/thread/openstep/SDL_systhread.c src/thread/openstep/SDL_sysmutex.c src/thread/openstep/SDL_syssem.c src/thread/openstep/SDL_syscond.c src/timer/SDL_timer.c src/timer/SDL_systimer.c src/core/SDL_maincore.c)

if (! -r $build_root/include/SDL.h) then
    echo "build-openstep-core: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $archive
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o

foreach source ($sources)
    if (! -r $build_root/$source) then
        echo "build-openstep-core: missing $source"
        exit 2
    endif
    @ number = $number + 1
    set object = $object_root/$number.o
    echo "CC $source"
    cc $cflags -c $build_root/$source -o $object
    if ($status != 0) exit 1
    set objects = ($objects $object)
end

ar cr $archive $objects
if ($status != 0) exit 1
ranlib $archive
if ($status != 0) exit 1
echo "build-openstep-core: PASS $archive ($number objects; prototype only)"
