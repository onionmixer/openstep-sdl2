#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/header-smoke.c
set test_object = /tmp/SDL20/build/header-smoke.o

if (! -r $build_root/include/SDL_config_openstep.h) then
    echo "compile-header-smoke: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -r $test_source) then
    echo "compile-header-smoke: staged test source is missing"
    exit 2
endif

rm -f $test_object
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -c $test_source -o $test_object
if ($status != 0) exit 1
echo "compile-header-smoke: PASS $test_object"
