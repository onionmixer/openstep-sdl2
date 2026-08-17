#!/bin/csh -f
# Compile common SDL2 GUID, CRC, sort, tokenizer and RWops implementations.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/common-utility-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/file -I$build_root/src/thread"
set sources = ($build_root/src/SDL_guid.c $build_root/src/stdlib/SDL_crc16.c $build_root/src/stdlib/SDL_crc32.c $build_root/src/stdlib/SDL_qsort.c $build_root/src/stdlib/SDL_strtokr.c $build_root/src/file/SDL_rwops.c)
set number = 0

if (! -r $build_root/src/file/SDL_rwops.c) then
    echo "compile-sdl-common-utilities-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-common-utilities-gate: PASS $number upstream utility objects (object only)"
