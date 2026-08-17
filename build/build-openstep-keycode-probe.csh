#!/bin/csh -f
# Build only; run this interactively from an OPENSTEP GUI Terminal.
set source_root = /tmp/SDL20/src
set output = /tmp/SDL20/bin/openstep-keycode-probe

if (! -r $source_root/test/openstep/openstep-keycode-probe.m) then
    echo "build-openstep-keycode-probe: run stage-openstep.csh first"
    exit 2
endif

cc -m486 -O -Wall -o $output $source_root/test/openstep/openstep-keycode-probe.m -framework AppKit -framework Foundation
if ($status != 0) exit 1
/bin/csh -f $source_root/port/openstep/fix-macho-i486-subtype.csh $output
if ($status != 0) exit 1
echo "build-openstep-keycode-probe: PASS $output (run from GUI Terminal)"
