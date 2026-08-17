#!/bin/csh -f
# Compile the native SDL2 SoundKit backend; this is an ABI/object gate only.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/openstep-audio-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/audio -I$build_root/src/audio/openstep"

if (! -r $build_root/src/audio/openstep/SDL_openstepaudio.m) then
    echo "compile-openstep-audio-bootstrap-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
cc $cflags -c $build_root/src/audio/openstep/SDL_openstepaudio.m -o $object_root/SDL_openstepaudio.o
if ($status != 0) exit 1
echo "compile-openstep-audio-bootstrap-gate: PASS SoundKit backend object (object only)"
