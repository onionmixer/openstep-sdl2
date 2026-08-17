#!/bin/csh -f
# Link the raw AppKit input probe; launch it directly through console GCD.
set test_source = /tmp/SDL20/src/test/openstep/openstep-appkit-input-record-probe.m
set test_binary = /tmp/SDL20/bin/openstep-appkit-input-record-probe

rm -f $test_binary
cc -m486 -Wall -D__OPENSTEP__ $test_source -framework AppKit -framework Foundation -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
echo "link-openstep-appkit-input-record-probe: PASS $test_binary (run directly through GCD)"
