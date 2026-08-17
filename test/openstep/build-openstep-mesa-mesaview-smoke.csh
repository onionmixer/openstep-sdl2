#!/bin/csh -f
# Compile Mesa 3.4.2's original OpenStep/MesaView renderer without altering it.
set mesa = /tmp/SDL20/mesa/Mesa-3.4.2
set view = $mesa/OpenStep/MesaView
set output = /tmp/SDL20/bin/openstep-mesa-mesaview-smoke
set source = /tmp/SDL20/src/test/openstep/openstep-mesa-mesaview-smoke.c

if (! -r $mesa/lib/libGL.a || ! -r $mesa/lib/libGLU.a || ! -r $view/mesadraw.c) then
    echo "build-openstep-mesa-mesaview-smoke: build and stage Mesa first"
    exit 2
endif

rm -f $output
cc -m486 -O -Wall -I$mesa/include -I$view $source $view/mesadraw.c $view/vect3d.c -L$mesa/lib -lGLU -lGL -lm -framework AppKit -framework Foundation -o $output
if ($status != 0) exit 1
csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $output
if ($status != 0) exit 1
$output
