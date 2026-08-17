#!/bin/csh -f
# Build the target-local exact UTF-8 Workspace fixture generator.
set test_source = /tmp/SDL20/src/test/openstep/openstep-create-utf8-fixture.c
set test_binary = /tmp/SDL20/bin/openstep-create-utf8-fixture

if (! -r $test_source) then
    echo "build-openstep-create-utf8-fixture: missing $test_source"
    exit 2
endif
rm -f $test_binary
cc -m486 -Wall $test_source -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
echo "build-openstep-create-utf8-fixture: PASS $test_binary"
