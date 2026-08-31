#!/bin/csh -f
# Link the unmodified SDL 2.32.10 testmultiaudio consumer and its upstream
# helper against the final OPENSTEP archive.  Its shipped sample.wav is copied
# beside the executable so the ordinary SDL_GetBasePath() CWD fallback works.
set build_root = /me/SDL20/build/SDL-2.32.10-openstep
set mesa = /me/SDL20/mesa/Mesa-3.4.2
set archive = $build_root/libSDL2.a
set upstream = /ndrv/openstep-sdl20/upstream/SDL-2.32.10/test
set test_binary = /me/SDL20/bin/upstream-sdl2-testmultiaudio

if (! -r $archive || ! -r $mesa/lib/libGL.a || ! -r $upstream/testmultiaudio.c || ! -r $upstream/testutils.c || ! -r $upstream/sample.wav) then
    echo "link-upstream-sdl2-testmultiaudio: missing final archive, Mesa, or upstream sample"
    exit 2
endif

rm -f $test_binary
cp $upstream/sample.wav /me/SDL20/bin/sample.wav
if ($status != 0) exit 1
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/events -I$build_root/src/render -I$build_root/src/video -I$build_root/src/thread -I$upstream $upstream/testmultiaudio.c $upstream/testutils.c $archive -L$mesa/lib -lGL -lm -framework AppKit -framework Foundation -framework SoundKit -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /me/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
cp /me/SDL20/src/test/openstep/run-upstream-sdl2-testmultiaudio.csh /me/SDL20/bin/run-upstream-sdl2-testmultiaudio.csh
if ($status != 0) exit 1
chmod 755 /me/SDL20/bin/run-upstream-sdl2-testmultiaudio.csh
if ($status != 0) exit 1
echo "link-upstream-sdl2-testmultiaudio: PASS $test_binary (run through GCD)"
