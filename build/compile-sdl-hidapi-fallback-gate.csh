#!/bin/csh -f
# Compile SDL's public HIDAPI dispatcher in OPENSTEP's configured disabled
# mode. This keeps every SDL_hid_* ABI symbol with standard no-backend
# behavior; it does not claim hardware HID support.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/SDL-hidapi-fallback-gate.o
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/hidapi -I$build_root/src/thread"

if (! -r $build_root/src/hidapi/SDL_hidapi.c) then
    echo "compile-sdl-hidapi-fallback-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
rm -f $object
cc $cflags -c $build_root/src/hidapi/SDL_hidapi.c -o $object
if ($status != 0) exit 1
echo "compile-sdl-hidapi-fallback-gate: PASS $object (standard disabled-HIDAPI object)"
