#!/bin/csh -f
# NeXT cc-744.13 can mark a -m486 executable as i586. OPENSTEP's i486
# loader rejects that result. After a successful link, rewrite only the
# Mach-O mach_header.cpusubtype byte (offset 8) from 5 to 4.

if ($#argv != 1) then
    echo "usage: fix-macho-i486-subtype.csh executable"
    exit 2
endif
if (! -f $argv[1]) then
    echo "fix-macho-i486-subtype: file not found: $argv[1]"
    exit 2
endif

/usr/bin/perl -0777 -pi -e 'substr($_,8,1)=chr(4)' $argv[1]
if ($status != 0) exit 1
otool -h $argv[1]
