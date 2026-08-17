#!/bin/csh -f
# Link SDL 2.32.10's unmodified fixed-function OpenGL sample (testgl2) and
# its upstream SDL_test support sources against the final OPENSTEP archive.
# The sources below remain in the upstream tree; this is target-side build
# plumbing only.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set mesa = /tmp/SDL20/mesa/Mesa-3.4.2
set archive = $build_root/libSDL2.a
set upstream_root = /ndrv/openstep-sdl20/upstream/SDL-2.32.10
set upstream_test = $upstream_root/test
set upstream_support = $upstream_root/src/test
set test_binary = /tmp/SDL20/bin/upstream-sdl2-testgl2

if (! -r $archive || ! -r $mesa/lib/libGL.a || ! -r $upstream_test/testgl2.c || ! -r $upstream_support/SDL_test_common.c || ! -r $upstream_support/SDL_test_font.c || ! -r $upstream_support/SDL_test_memory.c || ! -r $upstream_support/SDL_test_crc32.c) then
    echo "link-upstream-sdl2-testgl2: missing final archive, Mesa, or upstream test sources"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ -DHAVE_OPENGL -I$build_root/include -I$build_root/src -I$build_root/src/events -I$build_root/src/render -I$build_root/src/video -I$build_root/src/thread -I$upstream_root/include -I$upstream_test $upstream_test/testgl2.c $upstream_support/SDL_test_common.c $upstream_support/SDL_test_font.c $upstream_support/SDL_test_memory.c $upstream_support/SDL_test_crc32.c $archive -L$mesa/lib -lGL -lm -framework AppKit -framework Foundation -framework SoundKit -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
cp /tmp/SDL20/src/test/openstep/run-upstream-sdl2-testgl2.csh /tmp/SDL20/bin/run-upstream-sdl2-testgl2.csh
if ($status != 0) exit 1
chmod 755 /tmp/SDL20/bin/run-upstream-sdl2-testgl2.csh
if ($status != 0) exit 1
echo "link-upstream-sdl2-testgl2: PASS $test_binary (run through GCD; Escape exits)"
