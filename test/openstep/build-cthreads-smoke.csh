#!/bin/csh -f

set test_source = /tmp/SDL20/src/test/openstep/cthreads-smoke.c
set test_binary = /tmp/SDL20/bin/cthreads-smoke

rm -f $test_binary
cc -m486 -Wall $test_source -o $test_binary
if ($status != 0) exit 1
$test_binary
if ($status != 0) exit 1
echo "build-cthreads-smoke: PASS $test_binary"

