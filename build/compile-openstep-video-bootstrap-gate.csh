#!/bin/csh -f
# Compile the OPENSTEP video bootstrap/window/framebuffer/basic-event source.
# Keyboard mapping and complete event-core linking remain outside this gate.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set object = $build_root/openstep-video-bootstrap-gate.o
set mesa_include = /tmp/SDL20/mesa/Mesa-3.4.2/include
set cflags = "-m486 -O -Wall -D__OPENSTEP__ -I$build_root/include -I$build_root/src -I$build_root/src/video -I$build_root/src/video/openstep -I$mesa_include"

if (! -r $build_root/src/video/openstep/SDL_openstepvideo.m) then
    echo "compile-openstep-video-bootstrap-gate: run prepare-openstep-tree.csh first"
    exit 2
endif
if (! -r $mesa_include/GL/osmesa.h) then
    echo "compile-openstep-video-bootstrap-gate: stage Mesa-3.4.2 first"
    exit 2
endif

rm -f $object
cc $cflags -c $build_root/src/video/openstep/SDL_openstepvideo.m -o $object
if ($status != 0) exit 1
echo "compile-openstep-video-bootstrap-gate: PASS $object (bootstrap/window/framebuffer/events/OSMesa GL callbacks)"
