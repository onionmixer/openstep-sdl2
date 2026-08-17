#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/openstep-thread-backend-smoke.c
set test_binary = /tmp/SDL20/bin/openstep-thread-backend-smoke

if (! -r $build_root/src/thread/openstep/SDL_systhread.c) then
    echo "build-openstep-thread-backend-smoke: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread $test_source $build_root/src/thread/openstep/SDL_systhread.c $build_root/src/atomic/SDL_atomic.c $build_root/src/atomic/SDL_spinlock.c -o $test_binary
if ($status != 0) exit 1
$test_binary
if ($status != 0) exit 1
echo "build-openstep-thread-backend-smoke: PASS $test_binary"

