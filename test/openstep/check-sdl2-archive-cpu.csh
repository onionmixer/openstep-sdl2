#!/bin/csh -f
if ($#argv != 1) then
    echo "usage: check-sdl2-archive-cpu.csh /path/to/libSDL2.a"
    exit 2
endif
set archive = $argv[1]
set temp = /tmp/sdl2-archive-cpu-member.o
set bad = 0
foreach member (`ar t $archive`)
    if ("$member" == "__.SYMDEF") continue
    ar p $archive $member > $temp
    file $temp | grep i386 > /dev/null
    if ($status != 0) then
        echo "non-i386 member: $member"
        file $temp
        set bad = 1
    endif
end
rm -f $temp
if ($bad != 0) exit 1
echo "check-sdl2-archive-cpu: PASS all members i386"
