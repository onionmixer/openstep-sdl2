#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = /tmp/SDL20/build/thread-objects
set nonomatch

if (! -r $build_root/src/thread/openstep/SDL_systhread.c) then
    echo "compile-thread-backend: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o

cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread -c $build_root/src/thread/SDL_thread.c -o $object_root/SDL_thread.o
if ($status != 0) exit 1
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread -c $build_root/src/thread/openstep/SDL_systhread.c -o $object_root/SDL_openstep_systhread.o
if ($status != 0) exit 1
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/thread -c $build_root/src/thread/openstep/SDL_systls.c -o $object_root/SDL_systls.o
if ($status != 0) exit 1
echo "compile-thread-backend: PASS"
