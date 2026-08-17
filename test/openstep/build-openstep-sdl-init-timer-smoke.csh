#!/bin/csh -f
# Link the real SDL.c dispatcher closure into a private i486 executable and
# exercise the timer-only public SDL_Init/SDL_Quit route. No video or audio
# device is opened by this smoke.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set test_source = /tmp/SDL20/src/test/openstep/openstep-sdl-init-timer-smoke.c
set test_binary = /tmp/SDL20/bin/openstep-sdl-init-timer-smoke

if (! -r $build_root/SDL-init-closure-gate.o) then
    echo "build-openstep-sdl-init-timer-smoke: run link-sdl-init-closure-gate.csh first"
    exit 2
endif

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/timer $test_source $build_root/SDL-init-closure-gate.o -framework AppKit -framework Foundation -framework SoundKit -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
$test_binary
if ($status != 0) exit 1
echo "build-openstep-sdl-init-timer-smoke: PASS $test_binary"
