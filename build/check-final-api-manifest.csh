#!/bin/csh -f
# Verify the final OPENSTEP SDL archive contains each OpenStep-preprocessed
# upstream dynapi entry. This is an export gate, not behavioural proof.

if ($#argv != 1) then
    echo "usage: check-final-api-manifest.csh /path/to/libSDL2.a"
    exit 2
endif

# The target executes this only after stage-openstep.csh, whose fixed and
# documented private source location is /tmp/SDL20/src.  Old csh does not
# apply the :h pathname modifier to the special $0 variable reliably.
set archive = $argv[1]
set source_root = /tmp/SDL20/src
set manifest = $source_root/notes/SDL2.32.10.OPENSTEP_API_MANIFEST.txt
set symbols = /tmp/SDL20/build/final-sdl2-symbols.txt
set missing = /tmp/SDL20/build/final-sdl2-missing.txt
set raw_symbols = /tmp/SDL20/build/final-sdl2-symbols-raw.txt
set member_object = /tmp/SDL20/build/final-sdl2-member.o
set member_symbols = /tmp/SDL20/build/final-sdl2-member-symbols.txt

if (! -r $archive) then
    echo "check-final-api-manifest: cannot read $archive"
    exit 2
endif
if (! -r $manifest) then
    echo "check-final-api-manifest: cannot read $manifest"
    exit 2
endif

# OPENSTEP Mach-O nm prints a leading underscore for external C symbols;
# upstream declarations and the manifest do not. Its old nm can reject an
# archive-wide index if a valid member has no external name list, so final
# archives use short unique members and are inspected one member at a time.
set members = `ar t $archive | awk '/^m[0-9][0-9]*\.o$/ { print $0 }'`
if ($#members == 0) then
    echo "check-final-api-manifest: archive has no short final members"
    exit 2
endif
rm -f $symbols $missing $raw_symbols $member_object $member_symbols
foreach member ($members)
    ar p $archive $member > $member_object
    if ($status != 0) exit 1
    nm -g $member_object > $member_symbols
    if ($status == 0) then
        awk '/ [TDB] / { print substr($NF, 2) }' $member_symbols >> $raw_symbols
        if ($status != 0) exit 1
    endif
end
sort -u $raw_symbols > $symbols
if ($status != 0) exit 1
comm -23 $manifest $symbols > $missing
set missing_count = `wc -l < $missing`
if ($missing_count != 0) then
    echo "check-final-api-manifest: FAIL missing $missing_count API symbols"
    cat $missing
    exit 1
endif

set manifest_count = `wc -l < $manifest`
echo "check-final-api-manifest: PASS $manifest_count API symbols in $archive"
