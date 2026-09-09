#!/bin/csh -f
#
# Build openstep-sdl-scale-teapot.c -- both binaries, or one of them.
#
#   csh -f build-sdl-scale-teapot.csh [-sw | -hybrid] [prefix] <mesa-source-root>
#
# WHAT THIS IS FOR.  ANAYLIZE_SDL2_SOUND_OPTIMIZATION.md section 8.3: play
# an eight-note scale through an ordinary SDL2 audio device and find out
# whether a picture beside it makes the device run dry -- and which
# picture.  The program prints numbers, not a verdict; the analysis says
# how to read them.
#
#   scaleteapot_sw       stock libGL.a.   modes 0, 1, 3
#   scaleteapot_hybrid   libGL_mga.a.     modes 0, 1, 2, 3 (2 = Matrox present)
#
# Run:  ./scaleteapot_sw [seconds] [mode] [lockms] [w h]
#   e.g. ./scaleteapot_sw 60 0        the control: audio alone
#        ./scaleteapot_sw 60 1        teapot through AppKit
#        ./scaleteapot_hybrid 60 2    teapot through video memory
#        ./scaleteapot_sw 60 3        no picture, main thread spinning
#        ./scaleteapot_sw 60 1 50     AppKit, plus 50 ms of SDL_LockAudio a frame
#
# This mirrors openstep-matrox-remade/examples/build-sdl-teapot.csh: the
# same SDL2 prefix, the same flags, the same teapot geometry cut from Mesa
# at build time (it is not shipped -- see that project's NOTICE).
#
set want = both
set prefix = /LocalDeveloper
set mesasrc = ""
set argi = 1
if ($#argv >= 1) then
    if ("$argv[1]" == "-sw") then
        set want = sw
        set argi = 2
    else if ("$argv[1]" == "-hybrid") then
        set want = hybrid
        set argi = 2
    endif
endif
if ($#argv >= $argi) set prefix = "$argv[$argi]"
@ argi = $argi + 1
if ($#argv >= $argi) set mesasrc = "$argv[$argi]"
# csh evaluates both sides of &&, so an unset variable inside a compound
# condition is an error rather than a false.  Test it on its own line.
if ("$mesasrc" == "") then
    if ($?MESASRC) then
        set mesasrc = "$MESASRC"
    endif
endif

if ("$mesasrc" == "" || ! -r "$mesasrc/widgets-mesa/demos/tea.c") then
    echo "build-sdl-scale-teapot: need a Mesa 3.4.2 source tree for the teapot geometry"
    echo "build-sdl-scale-teapot: usage: csh -f build-sdl-scale-teapot.csh [-sw|-hybrid] [prefix] <mesa-source-root>"
    exit 1
endif
if (! -r $prefix/Libraries/libSDL2.a || ! -r $prefix/Headers/SDL2/SDL.h) then
    echo "build-sdl-scale-teapot: no SDL2 at $prefix"
    echo "build-sdl-scale-teapot: install OpenStepSDL2Libraries and OpenStepSDL2Headers"
    exit 1
endif

sed -n '581,730p' "$mesasrc/widgets-mesa/demos/tea.c" > teapot-geometry.h
if ($status != 0) exit 1
grep cpdata teapot-geometry.h > /dev/null
if ($status != 0) then
    echo "build-sdl-scale-teapot: the cut produced no control points -- is this Mesa 3.4.2?"
    exit 1
endif

# -m486 and -D__OPENSTEP__ are SDL2's: its public headers do not parse for
# this compiler without the second, and the archive is built with the first.
set sdlflags = "-m486 -D__OPENSTEP__ -I$prefix/Headers/SDL2"
set frameworks = "-framework AppKit -framework Foundation -framework SoundKit"

if ("$want" == "both" || "$want" == "sw") then
    if (! -r $prefix/Libraries/libGL.a) then
        echo "build-sdl-scale-teapot: no $prefix/Libraries/libGL.a"
        echo "build-sdl-scale-teapot: install OpenStepMesa342Libraries at $prefix"
        exit 1
    endif
    cc -O $sdlflags -I$prefix/Headers \
        openstep-sdl-scale-teapot.c $prefix/Libraries/libSDL2.a \
        $prefix/Libraries/libGL.a -lm $frameworks -o scaleteapot_sw
    if ($status != 0) exit 1
    echo "build-sdl-scale-teapot: PASS ./scaleteapot_sw (stock Mesa; modes 0 1 3)"
endif

if ("$want" == "both" || "$want" == "hybrid") then
    if (! -r $prefix/Libraries/libGL_mga.a) then
        echo "build-sdl-scale-teapot: no $prefix/Libraries/libGL_mga.a"
        echo "build-sdl-scale-teapot: install OpenStepMGAMesaAccel at $prefix, or use -sw"
        exit 1
    endif
    cc -O $sdlflags -I$prefix/Headers -DOSMGA_SCALE_ACCEL \
        openstep-sdl-scale-teapot.c $prefix/Libraries/libSDL2.a \
        $prefix/Libraries/libGL_mga.a -lm $frameworks -o scaleteapot_hybrid
    if ($status != 0) exit 1
    echo "build-sdl-scale-teapot: PASS ./scaleteapot_hybrid (modes 0 1 2 3)"
endif
