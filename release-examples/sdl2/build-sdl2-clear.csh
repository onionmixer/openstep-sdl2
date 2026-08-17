#!/bin/csh -f
set prefix = /LocalDeveloper
if ($#argv == 1) set prefix = $argv[1]
cc -m486 -arch i386 -D__OPENSTEP__ -I$prefix/Headers sdl2_clear.c $prefix/Libraries/libSDL2.a -L$prefix/Libraries -lGL -lm -framework AppKit -framework Foundation -framework SoundKit -o sdl2_clear
if ($status != 0) exit 1
file sdl2_clear | grep 'architecture i386' > /dev/null
if ($status != 0) then
    echo "build-sdl2-clear: compiler did not produce i386 Mach-O"
    exit 1
endif
echo "build-sdl2-clear: PASS ./sdl2_clear"
