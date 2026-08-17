#!/bin/csh -f
# Rebuild the upstream SDL2 demonstrations shipped beside this script.
set prefix = /LocalDeveloper
if ($#argv == 1) set prefix = $argv[1]
set root = `pwd`
set common = "$root/Support/SDL_test_common.c $root/Support/SDL_test_font.c $root/Support/SDL_test_memory.c $root/Support/SDL_test_crc32.c"
set flags = "-m486 -arch i386 -D__OPENSTEP__ -I$prefix/Headers -I$prefix/Headers/SDL2 -I$root/Upstream -I$root/Support"
set libs = "$prefix/Libraries/libSDL2.a -L$prefix/Libraries -lGL -lm -framework AppKit -framework Foundation -framework SoundKit"

cc $flags -DHAVE_OPENGL $root/Upstream/testgl11cube.c $common $libs -o testgl11cube
if ($status != 0) exit 1
cc $flags $root/Upstream/testspriteminimal.c $root/Upstream/testutils.c $libs -o testspriteminimal
if ($status != 0) exit 1
cc $flags $root/Upstream/testmultiaudio.c $root/Upstream/testutils.c $libs -o testmultiaudio
if ($status != 0) exit 1
cc $flags $root/Upstream/testthread.c $common $root/Support/SDL_test_log.c $libs -o testthread
if ($status != 0) exit 1
cc $flags $root/Upstream/testtimer.c $common $root/Support/SDL_test_assert.c $root/Support/SDL_test_log.c $libs -o testtimer
if ($status != 0) exit 1
echo "build-upstream-demos: PASS testgl11cube testspriteminimal testmultiaudio testthread testtimer"
