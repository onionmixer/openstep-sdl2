#!/bin/csh -f
# Build the historically selected non-LLVM Mesa 3.4.2 OpenStep target in the
# private target stage.  This is a Mesa dependency gate, not an SDL2 library.

set mesa_root = /tmp/SDL20/mesa/Mesa-3.4.2
set lib_root = $mesa_root/lib

if (! -r $mesa_root/Make-config || ! -r $mesa_root/docs/README.OpenStep) then
    echo "build-mesa-3.4.2-openstep-gate: run stage-openstep.csh first"
    exit 2
endif
if (! -x $mesa_root/bin/mklib.openstep) then
    echo "build-mesa-3.4.2-openstep-gate: missing OpenStep static-library tool"
    exit 2
endif

cd $mesa_root
make CC='cc -m486' openstep
if ($status != 0) exit 1

if (! -f $lib_root/libGL.a || ! -f $lib_root/libGLU.a) then
    echo "build-mesa-3.4.2-openstep-gate: expected libGL.a and libGLU.a"
    exit 1
endif
ar t $lib_root/libGL.a | grep osmesa.o
if ($status != 0) then
    echo "build-mesa-3.4.2-openstep-gate: libGL.a lacks the OSMesa member"
    exit 1
endif
nm $mesa_root/src/OSmesa/osmesa.o | grep OSMesaCreateContext
if ($status != 0) then
    echo "build-mesa-3.4.2-openstep-gate: OSMesa member lacks OSMesaCreateContext"
    exit 1
endif
echo "build-mesa-3.4.2-openstep-gate: PASS $lib_root/libGL.a $lib_root/libGLU.a"
