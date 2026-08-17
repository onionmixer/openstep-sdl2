#!/bin/csh -f
# Report, but do not mask, the public SDL2 symbol gap of a diagnostic archive.
# The release-only check-final-api-manifest.csh remains the pass/fail gate.

if ($#argv != 1) then
    echo "usage: report-sdl2-openstep-manifest.csh /path/to/archive"
    exit 2
endif

set archive = $argv[1]
set source_root = /tmp/SDL20/src
set manifest = $source_root/notes/SDL2.32.10.OPENSTEP_API_MANIFEST.txt
set symbols = /tmp/SDL20/build/diagnostic-sdl2-symbols.txt
set missing = /tmp/SDL20/build/diagnostic-sdl2-missing.txt
set raw_symbols = /tmp/SDL20/build/diagnostic-sdl2-symbols-raw.txt
set member_object = /tmp/SDL20/build/diagnostic-sdl2-member.o
set member_symbols = /tmp/SDL20/build/diagnostic-sdl2-member-symbols.txt

if (! -r $archive) then
    echo "report-sdl2-openstep-manifest: cannot read $archive"
    exit 2
endif
if (! -r $manifest) then
    echo "report-sdl2-openstep-manifest: cannot read $manifest"
    exit 2
endif

# OPENSTEP Mach-O nm prepends '_' to C externals; the manifest intentionally
# stores the upstream declaration spelling without it.  The target's nm can
# reject an archive-wide symbol table after ranlib has seen a symbol-less
# member, so inspect the short, unique archive members one by one instead.
set members = `ar t $archive | awk '/^m[0-9][0-9]*\.o$/ { print $0 }'`
if ($#members == 0) then
    echo "report-sdl2-openstep-manifest: no short diagnostic archive members"
    exit 2
endif
rm -f $symbols $missing $raw_symbols $member_object $member_symbols
foreach member ($members)
    ar p $archive $member > $member_object
    if ($status != 0) exit 1
    # A few valid input objects intentionally have no external name list.
    # Old nm exits nonzero for those; skip only that member rather than
    # rejecting the complete diagnostic archive.
    nm -g $member_object > $member_symbols
    if ($status == 0) then
        awk '/ [TDB] / { print substr($NF, 2) }' $member_symbols >> $raw_symbols
        if ($status != 0) exit 1
    endif
end
sort -u $raw_symbols > $symbols
if ($status != 0) exit 1
comm -23 $manifest $symbols > $missing
if ($status != 0) exit 1
set present_count = `comm -12 $manifest $symbols | wc -l`
set missing_count = `wc -l < $missing`
set manifest_count = `wc -l < $manifest`
echo "report-sdl2-openstep-manifest: $present_count/$manifest_count API symbols present; $missing_count missing"
if ($missing_count != 0) then
    echo "report-sdl2-openstep-manifest: NONRELEASE; detailed list is $missing"
endif
exit 0
