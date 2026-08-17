#!/bin/csh -f
# Link the exact static-Mesa mechanisms used by SDL's OpenStep GL driver.
set mesa = /tmp/SDL20/mesa/Mesa-3.4.2
set output = /tmp/SDL20/bin/openstep-mesa-context-matrix
set source = /tmp/SDL20/src/test/openstep/openstep-mesa-context-matrix.c

if (! -r $mesa/lib/libGL.a || ! -r $source) then
    echo "build-openstep-mesa-context-matrix: build Mesa and stage sources first"
    exit 2
endif

rm -f $output
cc -m486 -O -Wall -I$mesa/include $source -L$mesa/lib -lGL -lm -o $output
if ($status != 0) exit 1
csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $output
if ($status != 0) exit 1
$output
