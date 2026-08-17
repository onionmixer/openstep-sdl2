#!/bin/csh -f
# Build the Foundation/NSString Workspace-visible UTF-8 fixture generator.
set test_source = /tmp/SDL20/src/test/openstep/openstep-create-logical-utf8-fixture.m
set test_binary = /tmp/SDL20/bin/openstep-create-logical-utf8-fixture

if (! -r $test_source) then
    echo "build-openstep-create-logical-utf8-fixture: missing $test_source"
    exit 2
endif
rm -f $test_binary
cc -m486 -Wall $test_source -framework Foundation -o $test_binary
if ($status != 0) exit 1
/bin/csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $test_binary
if ($status != 0) exit 1
echo "build-openstep-create-logical-utf8-fixture: PASS $test_binary"
