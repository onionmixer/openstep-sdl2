#!/bin/csh -f

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = /tmp/SDL20/build/core-objects
set nonomatch
set sources = (SDL_error.c SDL_list.c SDL_dataqueue.c SDL_utils.c SDL_hints.c SDL_log.c)

if (! -r $build_root/src/SDL_error.c) then
    echo "compile-core-batch: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o

foreach source ($sources)
    echo "CC $source"
    cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/stdlib -c $build_root/src/$source -o $object_root/$source:r.o
    if ($status != 0) exit 1
end

echo "compile-core-batch: PASS"
