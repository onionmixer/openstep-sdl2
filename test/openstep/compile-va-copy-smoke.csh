#!/bin/csh -f

set test_source = /tmp/SDL20/src/test/openstep/va-copy-smoke.c
set test_object = /tmp/SDL20/build/va-copy-smoke.o

rm -f $test_object
cc -m486 -Wall -c $test_source -o $test_object
if ($status != 0) exit 1
echo "compile-va-copy-smoke: PASS $test_object"

