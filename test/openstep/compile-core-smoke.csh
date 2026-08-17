#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_object = /tmp/SDL20/build/SDL_error.o

if (! -r $build_root/src/SDL_error.c) then
    echo "compile-core-smoke: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $test_object
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -c $build_root/src/SDL_error.c -o $test_object
if ($status != 0) exit 1
echo "compile-core-smoke: PASS $test_object"

