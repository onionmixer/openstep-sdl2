#!/bin/csh -f
# Compile the complete upstream SDL2 audio core plus the standard dummy
# fallback. SoundKit integration is a separate OPENSTEP backend step.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object_root = $build_root/audio-core-objects
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/audio -I$build_root/src/audio/dummy -I$build_root/src/thread -I$build_root/src/timer"
set sources = ($build_root/src/audio/*.c $build_root/src/audio/dummy/SDL_dummyaudio.c)
set number = 0

if (! -r $build_root/src/audio/SDL_audio.c) then
    echo "compile-sdl-audio-core-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -d $object_root) mkdir $object_root
rm -f $object_root/*.o
foreach source ($sources)
    @ number = $number + 1
    cc $cflags -c $source -o $object_root/$number.o
    if ($status != 0) exit 1
end
echo "compile-sdl-audio-core-gate: PASS $number upstream audio objects (object only)"
