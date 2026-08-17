#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_object = /tmp/SDL20/build/SDL_string.o

if (! -r $build_root/src/stdlib/SDL_string.c) then
    echo "compile-stdlib-smoke: run prepare-openstep-tree.csh first"
    exit 2
endif

rm -f $test_object
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/stdlib -c $build_root/src/stdlib/SDL_string.c -o $test_object
if ($status != 0) exit 1
echo "compile-stdlib-smoke: PASS $test_object"

