#!/bin/csh -f
# Produce a candidate libSDL2.a only after every current compiler gate and the
# exact final public-API manifest gate pass.  Runtime/interactive coverage is
# recorded separately; this script validates the static-library ABI boundary.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set diagnostic = $build_root/libSDL2-diagnostic.a
set final = $build_root/libSDL2.a

csh -f /tmp/SDL20/src/build/build-sdl2-openstep-diagnostic-archive.csh
if ($status != 0) exit 1
if (! -r $diagnostic) then
    echo "build-sdl2-openstep-release-archive: diagnostic archive missing"
    exit 1
endif

# The diagnostic assembler already uses collision-free short object-member
# names required by the target ar. Copy only after its non-release report.
rm -f $final
cp $diagnostic $final
if ($status != 0) exit 1
# OPENSTEP's ar index stores the archive pathname.  A byte-for-byte copy from
# the diagnostic name therefore has an out-of-date table of contents when a
# normal static linker opens libSDL2.a; rebuild it after the final pathname is
# established, before declaring the release candidate usable.
ranlib $final
if ($status != 0) then
    rm -f $final
    exit 1
endif
csh -f /tmp/SDL20/src/build/check-final-api-manifest.csh $final
if ($status != 0) then
    rm -f $final
    exit 1
endif
echo "build-sdl2-openstep-release-archive: PASS $final"
