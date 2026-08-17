#!/bin/csh -f
# Link the native OPENSTEP modal-panel primitive probe (not an SDL test yet).
set test_source = /tmp/SDL20/src/test/openstep/openstep-modal-panel-probe.m
set test_binary = /tmp/SDL20/bin/openstep-modal-panel-probe

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ $test_source -framework AppKit -framework Foundation -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
echo "link-openstep-modal-panel-probe: PASS $test_binary (not run)"
